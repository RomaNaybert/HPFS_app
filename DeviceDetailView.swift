//
//  DeviceDetailView.swift
//  HPFS
//
//  Created by Роман on 08.08.2025.
//

//
//  DeviceDetailView.swift
//  HPFS
//
//  Created by Роман on 08.08.2025.
//

import SwiftUI
import Foundation

@MainActor
final class DeviceDetailViewModel: ObservableObject {
    @Published var device: Device
    @Published var lastUpdate: Date? = nil
    @Published var isLoading = false
    @Published var errorText: String? = nil

    // === РЕЛЕ ===
    @Published var isRelayOn = false
    @Published var isTogglingRelay = false
    private var lastRelayVersion: Int = -1

    // === НАСТРОЙКИ ===
    private var telemetryURL: URL {
        var c = URLComponents(url: API.base.appendingPathComponent("/telemetry/latest"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "device_id", value: device.id)]
        return c.url!
    }

    private var relaySetURL: URL { API.base.appendingPathComponent("/relay/set") }

    private var relayLastURL: URL {
        var c = URLComponents(url: API.base.appendingPathComponent("/relay/last"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "device_id", value: device.id)]
        return c.url!
    }
    
    private func makeRequest(url: URL, method: String = "GET", jsonBody: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let tok = APIClient.token(.access) {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        if let body = jsonBody {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private var pollTask: Task<Void, Never>?
    private var backoffSeconds: Double = 5
    private let maxBackoff: Double = 60

    init(device: Device) {
        self.device = device
    }

    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchOnce()
                // после датчиков — опрашиваем реле (long-poll-friendly по версии)
                await self.pollRelaySinceLastVersion()
                try? await Task.sleep(nanoseconds: UInt64(self.backoffSeconds * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func fetchNow() async {
        backoffSeconds = 5
        await fetchOnce()
        await pollRelaySinceLastVersion()
    }

    private func fetchOnce() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: telemetryURL))
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }
            let dto = try JSONDecoder().decode(TelemetryLatestDTO.self, from: data)

            if let h = dto.humidity { device.humidity = h }
            if let t = dto.temperature { device.temperature = Int(t.rounded()) }
            if let w = dto.water {
                device.isWaterAvailable = (w == "yes" || w == "true" || w == "1")
            }
            if let on = dto.online { device.isOnline = on }

            lastUpdate = Date()
            backoffSeconds = 5
        } catch {
            errorText = (error as NSError).localizedDescription
            backoffSeconds = min(maxBackoff, max(5, backoffSeconds * 1.7))
        }
    }

    // MARK: - Реле: GET /relay?since=version
    private func pollRelaySinceLastVersion() async {
        do {
            let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: relayLastURL))
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return }
            let dto = try JSONDecoder().decode(RelayLastDTO.self, from: data)
            lastRelayVersion = dto.version
            if let s = dto.state { isRelayOn = (s == "on") }
        } catch {
            // тихо игнорируем ошибки
        }
    }

    // MARK: - Реле: POST /relay {"state":"on"|"off"}
    func toggleRelay() async {
        await setRelay(!isRelayOn)
    }

    func setRelay(_ on: Bool) async {
        guard device.isOnline else { return }
        isTogglingRelay = true
        errorText = nil

        let prev = isRelayOn
        isRelayOn = on

        struct Body: Encodable { let device_id: String; let state: String }
        do {
            let body = try JSONEncoder().encode(Body(device_id: device.id, state: on ? "on" : "off"))
            let (data, resp) = try await URLSession.shared.data(for: makeRequest(url: relaySetURL, method: "POST", jsonBody: body))
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }
            let dto = try JSONDecoder().decode(RelayLastDTO.self, from: data)
            lastRelayVersion = dto.version
            if let s = dto.state { isRelayOn = (s == "on") }
        } catch {
            isRelayOn = prev
            errorText = "Не удалось переключить реле: \((error as NSError).localizedDescription)"
        }
        isTogglingRelay = false
    }
}

struct SensorDTO: Decodable {
    let humidity: Double?
    let temperature: Double?
    let water: String?
    let online: Bool?
}

struct RelayDTO: Decodable {
    let state: String   // "on" | "off"
    let version: Int
    let updated_at: Int?
}


struct DeviceDetailView: View {
    @StateObject private var vm: DeviceDetailViewModel

    init(device: Device) {
        _vm = StateObject(wrappedValue: DeviceDetailViewModel(device: device))
    }
    
    
    var body: some View {
        ScrollView {
            // --- твой красивый UI из прошлой версии ---
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)

            sensorCards
                .padding(.horizontal, 20)
                .padding(.top, 12)

            controls
                .padding(.horizontal, 20)
                .padding(.top, 12)

            footerStatus
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(gradientBG.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { vm.startPolling() }              // стартуем опрос при появлении
        .onDisappear { vm.stopPolling() }        // и останавливаем при уходе
        .refreshable { await vm.fetchNow() }     // pull-to-refresh
    }

    
    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await vm.toggleRelay() }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: vm.isRelayOn ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 24, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isRelayOn ? "Выключить насос" : "Включить насос")
                            .font(.headline)
                        Text(vm.isRelayOn ? "Реле: ВКЛ" : "Реле: ВЫКЛ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if vm.isTogglingRelay {
                        ProgressView()
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(vm.isRelayOn ? Color.green.opacity(0.18) : Color.gray.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25)))
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.device.isOnline || vm.isTogglingRelay)
            .animation(.easeInOut, value: vm.isRelayOn)
        }
    }

    // ==== ниже: заменяем device.* на vm.device.* ====
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.device.name)
                        .font(.system(size: 30, weight: .bold))

                    HStack(spacing: 8) {
                        statusBadge(
                            title: vm.device.isOnline ? "Онлайн" : "Оффлайн",
                            systemImage: vm.device.isOnline ? "dot.radiowaves.left.and.right" : "wifi.slash",
                            color: vm.device.isOnline ? .green : .gray
                        )
                        statusBadge(
                            title: vm.device.isWaterAvailable ? "Вода ок" : "Нет воды",
                            systemImage: vm.device.isWaterAvailable ? "drop.fill" : "drop.triangle",
                            color: vm.device.isWaterAvailable ? .blue : .orange
                        )
                    }
                }
                Spacer()
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "sensor.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                    )
                    .frame(width: 72, height: 72)
            }

            Divider().opacity(0.35)

            HStack(spacing: 10) {
                Image(systemName: "leaf").imageScale(.medium)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.device.plant.name.replacingOccurrences(of: "^[0-9]+", with: "", options: .regularExpression))
                        .font(.headline)
                    Text(vm.device.plant.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("#1")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(vm.device.plant.colorCard.opacity(0.2)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        )
    }

    private var sensorCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(
                    title: "Температура",
                    value: "\(vm.device.temperature)°C",
                    icon: "thermometer.sun",
                    gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.6)])
                )
                metricCard(
                    title: "Влажность",
                    value: "\(vm.device.humidity)%",
                    icon: "humidity.fill",
                    gradient: Gradient(colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.6)])
                )
            }
            HStack(spacing: 12) {
                metricCard(
                    title: "Пит. раствор",
                    value: vm.device.isWaterAvailable ? "Есть" : "Нет",
                    icon: "drop.fill",
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.indigo.opacity(0.6)])
                )
                metricCard(
                    title: "Связь",
                    value: vm.device.isOnline ? "Стабильна" : "Нет",
                    icon: vm.device.isOnline ? "wifi" : "wifi.slash",
                    gradient: Gradient(colors: [Color.green.opacity(0.6), Color.teal.opacity(0.6)])
                )
            }
        }
        .redacted(reason: vm.isLoading ? .placeholder : [])
        .animation(.easeInOut, value: vm.isLoading)
    }

    
    private var footerStatus: some View {
        HStack(spacing: 8) {
            if let t = vm.lastUpdate {
                Label("Обновлено \(t.formatted(date: .omitted, time: .standard))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let err = vm.errorText {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
    

    // MARK: — вспомогательные сабвью (как раньше)
    private var gradientBG: some View {
        LinearGradient(colors: [
            vm.device.colorCard.opacity(0.35),
            Color.black.opacity(0.05),
            Color(.secondarySystemBackground)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func statusBadge(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }

    private func metricCard(title: String, value: String, icon: String, gradient: Gradient) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: icon).imageScale(.medium); Spacer() }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.25)))
        )
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}


#Preview {
    DeviceDetailView(
        device: Device(
            id: "-1",
            name: "Автополив HPFS",
            plant: Plant(
                serverId: 1,
                name: "1Замиокулькас",
                location: "в кабинете",
                colorCard: Color("ColorCardPastelGreen"),
                colorNumber: .white,
                colorCardCitcle: Color(red: 39/255, green: 39/255, blue: 39/255),
                humidity: 84,
                temperature: 22
            ),
            colorCard: Color("ColorCardPastelGreen"),
            colorNumber: .white,
            colorCardCitcle: Color(red: 39/255, green: 39/255, blue: 39/255),
            humidity: 84,
            temperature: 22,
            isWaterAvailable: true,
            isOnline: true
        )
    )
}
