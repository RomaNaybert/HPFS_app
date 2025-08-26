//
//  DeviceClaimView.swift
//  HPFS
//
//  Created by Роман on 11.08.2025.
//

import SwiftUI

struct ClaimRequest: Codable { let claimCode: String }
struct RelayPushBody: Codable { let state: String }

// MARK: - API

@MainActor
final class HPFSClient {
    // ВРЕМЕННО: заменим на JWT в Keychain, когда подключим боевую авторизацию
    private let userIdHeader = "1"
    
    func claim(_ code: String) async throws {
        var req = URLRequest(url: API.base.appendingPathComponent("account/claim"))
        req.httpMethod = "POST"
        req.addValue(userIdHeader, forHTTPHeaderField: "X-User-Id")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(ClaimRequest(claimCode: code))

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("HTTP \( (resp as? HTTPURLResponse)?.statusCode ?? -1) \(req.url!.absoluteString) -> \(body)")
                throw APIError.badResponse
            }
        } catch {
            print("NETWORK ERROR \(req.url!.absoluteString): \(error)")
            throw error
        }
    }
    
    func myDevices() async throws -> [DeviceDTO] {
        var req = URLRequest(url: API.base.appendingPathComponent("devices"))
        req.addValue(userIdHeader, forHTTPHeaderField: "X-User-Id")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError.badResponse
        }
        return try JSONDecoder().decode(DevicesResponse.self, from: data).devices
    }
    
    func pushRelay(deviceId: String, on: Bool) async throws -> Int {
        var req = URLRequest(url: API.base.appendingPathComponent("relay/push/\(deviceId)"))
        req.httpMethod = "POST"
        req.addValue(userIdHeader, forHTTPHeaderField: "X-User-Id")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RelayPushBody(state: on ? "on" : "off"))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError.badResponse
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["version"] as? Int ?? -1
    }
}

// MARK: - ViewModel

@MainActor
final class DeviceClaimVM: ObservableObject {
    @Published var claimCode: String = ""
    @Published var isClaiming = false
    @Published var claimStatus: String?
    @Published var devices: [DeviceDTO] = []
    @Published var isRefreshing = false
    
    private let api = HPFSClient()
    private var pollTask: Task<Void, Never>?
    
    func loadDevices() async {
        do {
            isRefreshing = true
            let list = try await api.myDevices()
            withAnimation { self.devices = list }
        } catch {
            // можно показать Toast
        }
        isRefreshing = false
    }
    
    /// Привязать код и подождать появления устройства до 30 сек (poll каждые 2 сек)
    func claimAndWaitAppearance() {
        guard !claimCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            claimStatus = "Введи claim‑код"
            return
        }
        claimStatus = nil
        isClaiming = true
        
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await api.claim(self.claimCode.trimmingCharacters(in: .whitespacesAndNewlines))
                self.claimStatus = "Ожидаем устройство…"
                
                // 15 попыток × 2 сек = ~30 сек ожидание hello
                for attempt in 1...15 {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    let list = try await api.myDevices()
                    
                    // Эвристика: девайсов стало больше ИЛИ появился online == 1 недавно
                    if list.count > self.devices.count || list.contains(where: { $0.online == 1 }) {
                        withAnimation { self.devices = list }
                        self.claimStatus = "Готово! Устройство привязано."
                        self.isClaiming = false
                        self.claimCode = ""
                        return
                    } else {
                        self.claimStatus = "Ожидаем устройство… (\(attempt)/15)"
                    }
                }
                self.claimStatus = "Не дождались. Проверь Wi‑Fi устройства и код."
            } catch {
                self.claimStatus = (error as? LocalizedError)?.errorDescription ?? "Ошибка привязки"
            }
            self.isClaiming = false
        }
    }
    
    func toggleRelay(for device: DeviceDTO, desiredOn: Bool) async {
        do {
            _ = try await api.pushRelay(deviceId: device.id, on: desiredOn)
            // Опционально — сразу перезагрузить список
            await loadDevices()
        } catch {
            claimStatus = "Не удалось отправить команду реле"
        }
    }
}

// MARK: - View

struct DeviceClaimView: View {
    @StateObject private var vm = DeviceClaimVM()
    @FocusState private var focused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GroupBox("Привязка устройства") {
                    VStack(spacing: 12) {
                        HStack {
                            TextField("Введите claim‑код", text: $vm.claimCode)
                                .textInputAutocapitalization(.characters)
                                .disableAutocorrection(true)
                                .focused($focused)
                            
                            Button {
                                vm.claimAndWaitAppearance()
                                focused = false
                            } label: {
                                if vm.isClaiming {
                                    ProgressView()
                                } else {
                                    Text("Привязать")
                                        .bold()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isClaiming || vm.claimCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let s = vm.claimStatus, !s.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                Text(s)
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.top, 4)
                }
                
                GroupBox("Мои устройства") {
                    if vm.devices.isEmpty && !vm.isRefreshing {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView("Пока пусто",
                                                   systemImage: "wifi.router",
                                                   description: Text("Привяжите устройство по claim‑коду"))
                                .frame(maxWidth: .infinity)
                        } else {
                            EmptyStateView(title: "Пока пусто",
                                           systemImage: "wifi.router",
                                           subtitle: "Привяжите устройство по claim‑коду")
                        }
                    } else {
                        List {
                            ForEach(vm.devices) { dev in
                                DeviceRow(device: dev) {
                                    Task { await vm.toggleRelay(for: dev, desiredOn: true) }
                                } onOff: {
                                    Task { await vm.toggleRelay(for: dev, desiredOn: false) }
                                }
                            }
                        }
                        .listStyle(.inset)
                        .frame(maxHeight: 360)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("HPFS · Привязка")
            .task { await vm.loadDevices() }
            .refreshable { await vm.loadDevices() }
        }
    }
}

private struct DeviceRow: View {
    let device: DeviceDTO
    let onOn: () -> Void
    let onOff: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill((device.online == 1) ? .green.opacity(0.85) : .red.opacity(0.8))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.id)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("FW: \(device.fw ?? "—")")
                    if let ts = device.last_seen_at { Text("ts: \(ts)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Новая строка с показателями
                HStack(spacing: 12) {
                    if let h = device.humidity {
                        Text("Влажность: \(h)%")
                    } else {
                        Text("Влажность: —")
                    }
                    if let w = device.water {
                        Text("Вода: " + (w == 0 ? "нет" : "есть"))
                    } else {
                        Text("Вода: —")
                    }
                }
                .font(.caption)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("ON", action: onOn)
                    .buttonStyle(.borderedProminent)
                Button("OFF", action: onOff)
                    .buttonStyle(.bordered)
            }
            .labelStyle(.titleOnly)
        }
        .contentShape(Rectangle())
    }
}

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview{
    DeviceClaimView()
}
