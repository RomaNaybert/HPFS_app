//
//  TestDeviceUI.swift
//  HPFS
//
//  Created by Роман on 12.08.2025.
//

import SwiftUI

// MARK: - Models
struct HPFSDevice: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var plantName: String?
    var isOnline: Bool
    var avatar: String? // system image name or asset name
    var lastSeen: Date?
}

struct SensorSnapshot: Codable, Hashable {
    var humidity: Double?      // % почвы
    var temperature: Double?   // °C воздуха/почвы
    var waterLevel: Double?    // % бака
    var soilEC: Double?        // мСм/см — если есть
    var updatedAt: Date        // серверное время
}

// MARK: - Service
protocol DeviceServicing {
    func loadDevice(deviceId: UUID) async throws -> HPFSDevice
    func loadSensors(deviceId: UUID) async throws -> SensorSnapshot
    func togglePump(deviceId: UUID, on: Bool) async throws
    func startCalibration(deviceId: UUID) async throws
}

final class DeviceService: DeviceServicing {
    private let session = URLSession(configuration: .default)
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func loadDevice(deviceId: UUID) async throws -> HPFSDevice {
        #if DEBUG
        return HPFSDevice(id: deviceId, name: "Kandinsky #1", plantName: "Спатифиллум", isOnline: true, avatar: "leaf.circle.fill", lastSeen: .now)
        #else
        let url = API.base.appending(path: "/devices/\(deviceId.uuidString)")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(HPFSDevice.self, from: data)
        #endif
    }

    func loadSensors(deviceId: UUID) async throws -> SensorSnapshot {
        #if DEBUG
        return SensorSnapshot(humidity: Double(Int.random(in: 55...99)), temperature: Double.random(in: 20...27).rounded(), waterLevel: Double(Int.random(in: 20...100)), soilEC: nil, updatedAt: .now)
        #else
        let url = API.base.appending(path: "/devices/\(deviceId.uuidString)/sensors")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SensorSnapshot.self, from: data)
        #endif
    }

    func togglePump(deviceId: UUID, on: Bool) async throws {
        #if DEBUG
        try await Task.sleep(nanoseconds: 400_000_000)
        #else
        var req = URLRequest(url: API.base.appending(path: "/devices/\(deviceId.uuidString)/pump"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["state": on ? "on" : "off"])
        _ = try await session.data(for: req)
        #endif
    }

    func startCalibration(deviceId: UUID) async throws {
        #if DEBUG
        try await Task.sleep(nanoseconds: 600_000_000)
        #else
        let url = API.base.appending(path: "/devices/\(deviceId.uuidString)/calibrate")
        _ = try await session.data(from: url)
        #endif
    }
}

// MARK: - ViewModel
@MainActor
final class DeviceDetailVM: ObservableObject {
    @Published var device: HPFSDevice
    @Published var sensors: SensorSnapshot?
    @Published var isLoading = false
    @Published var isPumping = false
    @Published var error: String?

    private let service: DeviceServicing
    private var pollTask: Task<Void, Never>?

    init(device: HPFSDevice, service: DeviceServicing = DeviceService()) {
        self.device = device
        self.service = service
    }

    func onAppear() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            await self.reloadAll()
            // Poll every 7s
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                await self.reloadSensors()
            }
        }
    }

    func onDisappear() {
        pollTask?.cancel()
    }

    func reloadAll() async {
        await reloadDevice()
        await reloadSensors()
    }

    func reloadDevice() async {
        do {
            let d = try await service.loadDevice(deviceId: device.id)
            device = d
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reloadSensors() async {
        do {
            let s = try await service.loadSensors(deviceId: device.id)
            withAnimation(.easeOut(duration: 0.25)) { sensors = s }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePump() async {
        guard !isPumping else { return }
        isPumping = true
        defer { isPumping = false }
        do { try await service.togglePump(deviceId: device.id, on: true) } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - UI
struct DeviceDetailView2: View {
    @StateObject private var vm: DeviceDetailVM
    @Environment(\.dismiss) private var dismiss
    @State private var showCalibrate = false

    init(device: HPFSDevice) {
        _vm = StateObject(wrappedValue: DeviceDetailVM(device: device))
    }

    var body: some View {
        ZStack {
            BackgroundLeaves()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    quickActions
                    metricsGrid
                    notificationsCard
                    deviceBindingCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbar }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .sheet(isPresented: $showCalibrate) {
            CalibrationView(deviceName: vm.device.name)
                .presentationDetents([.height(420), .large])
        }
        .alert("Ошибка", isPresented: .constant(vm.error != nil), actions: {
            Button("Ок", role: .cancel) { vm.error = nil }
        }, message: { Text(vm.error ?? "") })
    }

    // MARK: Sections
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                Image(systemName: vm.device.avatar ?? "leaf")
                    .font(.system(size: 26, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.device.name)
                    .font(.system(size: 26, weight: .bold))
                HStack(spacing: 8) {
                    StatusDot(isOn: vm.device.isOnline)
                    Text(vm.device.isOnline ? "Онлайн" : "Оффлайн")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let last = vm.device.lastSeen {
                        Text("• ") + Text(last, style: .relative)
                    }
                }
            }
            Spacer()
            Button { showCalibrate = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Калибровка и настройки")
        }
        .glass()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            ActionButton(title: "Полив", icon: "drop.fill", busy: vm.isPumping) {
                await vm.togglePump()
            }
            .accessibilityHint("Запустить полив на устройстве")

            ActionButton(title: "Калибровка", icon: "ruler") {
                showCalibrate = true
            }

            ActionButton(title: "Обновить", icon: "arrow.clockwise") {
                await vm.reloadSensors()
            }
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Показания")
                .font(.title3.bold())
                .padding(.horizontal, 6)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(title: "Влажность", value: percent(vm.sensors?.humidity), systemImage: "humidity.fill")
                MetricTile(title: "Температура", value: degrees(vm.sensors?.temperature), systemImage: "thermometer")
                MetricTile(title: "Уровень воды", value: percent(vm.sensors?.waterLevel), systemImage: "water.waves")
                if let ec = vm.sensors?.soilEC {
                    MetricTile(title: "EC", value: String(format: "%.2f", ec), systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
            }
        }
        .glass()
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Уведомления")
                    .font(.title3.bold())
                Spacer()
            }
            Toggle(isOn: .constant(true)) {
                Text("Напоминать о поливе каждые 3 дня")
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.green.opacity(0.8)))
        }
        .glass()
    }

    private var deviceBindingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Привязка")
                .font(.title3.bold())
            HStack {
                Image(systemName: "leaf.fill")
                Text(vm.device.plantName ?? "Не привязано")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    PlantPickerView(selected: .constant(nil))
                } label: {
                    Text("Изменить")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .glass()
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        return ToolbarItem(placement: .principal) {
            Text("Устройство")
                .font(.headline)
        }
    }

    // MARK: Helpers
    private func percent(_ value: Double?) -> String { value.map { "\(Int($0.rounded()))%" } ?? "—" }
    private func degrees(_ value: Double?) -> String { value.map { "\(Int($0.rounded()))°C" } ?? "—" }
}

// MARK: - Subviews
struct ActionButton: View {
    var title: String
    var icon: String
    var busy: Bool = false
    var action: () async -> Void

    init(title: String, icon: String, busy: Bool = false, action: @escaping () async -> Void) {
        self.title = title; self.icon = icon; self.busy = busy; self.action = action
    }

    var body: some View {
        Button(action: { Task { await action() } }) {
            HStack(spacing: 8) {
                if busy { ProgressView().controlSize(.small) } else { Image(systemName: icon) }
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: systemImage); Spacer() }
            Text(value)
                .font(.system(size: 28, weight: .bold))
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StatusDot: View {
    let isOn: Bool
    var body: some View {
        Circle()
            .fill(isOn ? Color.green : Color.gray.opacity(0.6))
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(.white.opacity(0.6)))
            .shadow(radius: 1, y: 0.5)
    }
}

struct BackgroundLeaves: View {
    var body: some View {
        LinearGradient(colors: [Color.white, Color.green.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay(
                Image("leaves_bg") // опциональный бэк из твоих экранов
                    .resizable()
                    .scaledToFill()
                    .opacity(0.18)
                    .blur(radius: 8)
                    .ignoresSafeArea()
            )
    }
}

struct CalibrationView: View {
    var deviceName: String
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1

    var body: some View {
        VStack(spacing: 16) {
            Capsule().frame(width: 44, height: 5).foregroundStyle(.secondary.opacity(0.4)).padding(.top, 8)
            Text("Калибровка датчика")
                .font(.title2.bold())
            Text("Устройство: \(deviceName)")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Label("Погрузите датчик влажности в воду и нажмите \"Записать мокро\".", systemImage: "1.circle")
                Label("Высушите датчик и нажмите \"Записать сухо\".", systemImage: "2.circle")
            }
            .padding()
            .glass()

            HStack(spacing: 12) {
                Button("Записать мокро") { step = 2 }
                    .buttonStyle(FilledCapsule())
                Button("Записать сухо") { dismiss() }
                    .buttonStyle(FilledCapsule())
            }
            Spacer()
        }
        .padding()
        .background(BackgroundLeaves())
    }
}

struct PlantPickerView: View {
    @Binding var selected: String?
    var body: some View {
        List {
            ForEach(["Спатифиллум", "Фикус", "Замиокулькас"], id: \.self) { plant in
                Button { selected = plant } label: {
                    HStack { Image(systemName: "leaf.fill"); Text(plant); Spacer() }
                }
            }
        }
        .navigationTitle("Выбор растения")
    }
}

// MARK: - Modifiers & Styles
struct Glass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}
extension View { func glass() -> some View { modifier(Glass()) } }

struct FilledCapsule: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.black.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Preview
struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DeviceDetailView2(device: HPFSDevice(id: UUID(), name: "Kandinsky", plantName: "Спатифиллум", isOnline: true, avatar: "leaf.fill", lastSeen: .now))
        }
//        .environment(\._colorScheme, .light)
    }
}
