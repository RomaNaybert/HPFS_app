//
//  AddDeviceView.swift
//  HPFS
//
//  Created by Роман on 18.08.2025.
//

import SwiftUI
import NetworkExtension
import Combine



// MARK: - Конфиг
enum HPFSConfig {
    /// Локальный адрес устройства в режиме точки доступа (ESP8266/ESP32 по умолчанию так делает)
    static let deviceAPBaseURL = URL(string: "http://192.168.4.1")! // подмени при необходимости
    static let deviceAPPassword = "setup1234"
    /// Эндпоинты на устройстве
    static let helloPath = "/hello"
    static let scanPath  = "/wifi/scan"
    static let configPath = "/wifi/config"
    /// Bonjour-сервис устройства в домашней сети
    static let bonjourServiceType = "_hpfs._tcp."
    static let bonjourDomain = "local."
}

// MARK: - Модель состояний флоу
// фрагменты для твоего AddDeviceView.swift

enum AddStage: Equatable {
    case enterClaim
    case connectAP       // NEHotspotConfiguration к HPFS_SETUP_<code>
    case talkingToDevice // /hello, /scan
    case sendWiFi        // /provision
    case waitOnline      // опрос /claims/status и /devices
    case selectPlant(deviceId: String)
    case done
}



@MainActor
final class AddDeviceViewModel: ObservableObject {
    @Published var stage: AddStage = .enterClaim
    @Published var apCode: String = ""      // 3 цифры из SSID точки: HPFS_SETUP_<apCode>
    @Published var claimCode: String = ""   // одноразовый код сервера для привязки
    @Published var networks: [String] = []
    @Published var selectedSSID: String = ""
    @Published var wifiPass: String = ""
    @Published var deviceId: String? = nil
    @Published var error: String?
    @Published var plants: [Plant] = []
    @Published var selectedPlantID: Int? = nil

    var onDeviceClaimed: ((String, Plant) -> Void)?

    // Держим ссылку на актор-дирижёр
    private var discovery: DeviceDiscovery?

    // ЕДИНСТВЕННЫЙ корректный способ остановить поиск (без захвата self в Task).
    @MainActor
    func stopAutoDiscovery() {
        discovery?.cancel()
        discovery = nil
    }
    
    @MainActor
    func forceAttachNow() async {
        let id = "hpfs-\(claimCode)"
        guard selectedPlantID != nil else {
            self.error = "Выберите растение"; return
        }
        await finalizeAttachAndRefresh(deviceID: id)
    }
    
    @MainActor
    private func attachThenPoll(deviceID: String, plantId: Int, claim: String) async {
        // 1) Привязка
        do {
            try await DeviceAPI.attach(deviceID: deviceID, plantId: plantId, claim: claim)
        } catch {
            self.error = "Не удалось привязать устройство: \(error.localizedDescription)"
            return
        }

        // 2) Ждём, пока на сервере появится owner_id == мой
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            do {
                var comps = URLComponents(url: API.base.appendingPathComponent("/devices/lookup"),
                                          resolvingAgainstBaseURL: false)!
                comps.queryItems = [URLQueryItem(name: "device_id", value: deviceID)]
                let (data, resp) = try await URLSession.shared.data(from: comps.url!)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }

                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                    let myId = Auth.shared.userId
                    let owner = obj["owner_id"] as? Int
                    let attached = obj["ownerAttached"] as? Bool

                    if (myId != nil && owner == myId) || (attached == true) {
                        await DeviceStore.shared.reloadFromServer()
                        if let plant = plants.first(where: { $0.serverId == plantId }) {
                            onDeviceClaimed?(deviceID, plant)
                        }
                        withAnimation(.snappy) { stage = .done }
                        return
                    }
                }
                // поддержим ещё и массив
                if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]],
                   let first = arr.first {
                    let myId = Auth.shared.userId
                    let owner = first["owner_id"] as? Int
                    let attached = first["ownerAttached"] as? Bool
                    if (myId != nil && owner == myId) || (attached == true) {
                        await DeviceStore.shared.reloadFromServer()
                        if let plant = plants.first(where: { $0.serverId == plantId }) {
                            onDeviceClaimed?(deviceID, plant)
                        }
                        withAnimation(.snappy) { stage = .done }
                        return
                    }
                }
            } catch { /* продолжаем ждать */ }
        }

        self.error = "Не дождались подтверждения привязки от сервера"
    }
    
    // MARK: - Авто-поиск: завершение и финализация

    private func tryHelloAndFinish(host: String?, port: Int, fallbackId: String) async {
        // host вида "hpfs-785.local." → нормализуем
        let hostClean = (host ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // если резолва нет — завершаем по fallback
        guard !hostClean.isEmpty else {
            await MainActor.run { self.finishDiscovery(deviceID: fallbackId) }
            return
        }

        var comps = URLComponents()
        comps.scheme = "http"
        comps.host   = hostClean
        if port > 0 { comps.port = port }
        comps.path   = "/hello"

        guard let url = comps.url else {
            await MainActor.run { self.finishDiscovery(deviceID: fallbackId) }
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 2.0

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                struct HelloResp: Decodable { let device_id: String? }
                if let dec = try? JSONDecoder().decode(HelloResp.self, from: data),
                   let id = dec.device_id, !id.isEmpty {
                    await MainActor.run { self.finishDiscovery(deviceID: id) }
                    return
                }
            }
        } catch {
            // игнор — пойдём по fallback ниже
        }

        await MainActor.run { self.finishDiscovery(deviceID: fallbackId) }
    }

    @MainActor
    private func finishDiscovery(deviceID: String) {
        if let d = discovery { Task { await d.cancel() } }
        discovery = nil
        self.deviceId = deviceID
        withAnimation(.snappy) { stage = .done }
    }

    private func postJSON(path: String, json: [String: Any], timeout: TimeInterval = 8) async throws {
        let url = API.base.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        req.timeoutInterval = timeout
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Завершаем привязку на сервере и обновляем локальный список устройств (через onDeviceClaimed вы уже это делаете).
    @MainActor
    private func finalizeAttachAndRefresh(deviceID: String) async {
        self.deviceId = deviceID
        guard let pid = selectedPlantID else {
            self.error = "Не выбрано растение для устройства"
            return
        }
        await attachThenPoll(deviceID: deviceID, plantId: pid, claim: claimCode)
    }
    
    @MainActor
    private func waitOwnerAndRefresh(deviceID: String, plantId: Int) async {
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            var u = URLComponents(url: API.base.appendingPathComponent("/devices"), resolvingAgainstBaseURL: false)!
            u.queryItems = [.init(name: "device_id", value: deviceID)]
            do {
                let (data, _) = try await URLSession.shared.data(from: u.url!)
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                   let owner = obj["owner_id"] as? Int,
                   let myId = Auth.shared.userId, owner == myId {
                    await DeviceStore.shared.reloadFromServer()
                    withAnimation(.snappy) { stage = .done }
                    return
                }
            } catch { /* продолжаем ждать */ }
        }
        self.error = "Не дождались подтверждения привязки от сервера"
    }

    // Авто‑поиск запускаем один раз, события потребляем на MainActor
    @MainActor
    func beginAutoDiscovery() {
        stopAutoDiscovery()
        let code = claimCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        stage = .waitOnline

        // Адаптер к вашему API
        // Публичный lookup (не требует JWT) + claims/status
        func apiCall(_ path: String, _ q: [String:String]) async throws -> Data {
            var p = path
            var qItems = q

            // КАНОНИЧЕСКО: если спрашиваем конкретный девайс, ходим в /devices/lookup
            if path == "/devices" {
                p = "/devices/lookup"
            }
            // Нормализуем device_id «hpfs-<code>» если прилетает просто code
            if let dev = q["device_id"], !dev.isEmpty, !dev.hasPrefix("hpfs-") {
                qItems["device_id"] = "hpfs-\(dev)"
            }

            var comps = URLComponents(url: API.base.appendingPathComponent(p), resolvingAgainstBaseURL: false)!
            comps.queryItems = qItems.map { URLQueryItem(name: $0.key, value: $0.value) }
            var req = URLRequest(url: comps.url!)
            req.timeoutInterval = 5.5

            let (d, r) = try await URLSession.shared.data(for: req)
            guard let http = r as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return d
        }

        func parseServer(_ data: Data) throws -> String? {
            // /devices/lookup может вернуть объект {id/device_id/...} ИЛИ массив [{...}]
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                if let id = (obj["device_id"] as? String) ?? (obj["id"] as? String), !id.isEmpty { return id }
            }
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]],
               let first = arr.first {
                if let id = (first["device_id"] as? String) ?? (first["id"] as? String), !id.isEmpty { return id }
            }
            // /claims/status → {device_id:"..."}
            struct St: Decodable { let device_id: String? }
            if let st = try? JSONDecoder().decode(St.self, from: data),
               let id = st.device_id, !id.isEmpty { return id }

            return nil
        }

        let d = DeviceDiscovery()
        discovery = d
        let stream = d.run(
            code: code,
            overallTimeout: 60,
            localWindow: 12,
            api: apiCall,
            parseServerSeen: parseServer
        )

        Task { [weak self] in
            guard let self else { return }
            for await ev in stream {
                await self.handleDiscoveryEvent(ev)
            }
        }
    }
    
    @MainActor
    private func handleDiscoveryEvent(_ ev: DiscoveryEvent) async {
        switch ev {
        case .started(_):             stage = .waitOnline
        case .bonjourFound:           break
        case .helloOK(let id), .serverSeen(let id), .finished(let id):
            stopAutoDiscovery()
            if selectedPlantID != nil {
                await finalizeAttachAndRefresh(deviceID: id)
            } else {
                finishDiscovery(deviceID: id)
            }
        case .timeout:
            error = "Не удалось найти устройство. Проверьте, что оно в вашей Wi‑Fi сети."
        case .cancelled:              break
        case .error(let msg):         error = msg
        }
    }

    private struct HelloResp: Decodable { let device_id: String? }

    // храним, чтобы остановить при уходе со страницы
    private var _bonjour: BonjourWatcher?

    // запрашиваем сервер: сначала по device_id, затем claims/status
    private func pollServerForDevice(code: String) async throws -> String? {
        // /devices/lookup?device_id=hpfs-xxx  ← публичный эндпоинт
        do {
            var comps = URLComponents(url: API.base.appendingPathComponent("/devices/lookup"),
                                      resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "device_id", value: "hpfs-\(code)")]

            let (data, resp) = try await URLSession.shared.data(from: comps.url!)
            guard let http = resp as? HTTPURLResponse else { return nil }
            // 404/401/др. — считаем «не найдено»
            guard (200..<300).contains(http.statusCode) else { return nil }

            // сервер может вернуть объект или массив — поддержим оба варианта
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = obj["device_id"] as? String, !id.isEmpty {
                return id
            }
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let id = arr.first?["device_id"] as? String, !id.isEmpty {
                return id
            }
        } catch {
            // игнор – вернём nil ниже
        }

        // резервный шаг: спросить claim‑статус (тоже публичный)
        do {
            var comps = URLComponents(url: API.base.appendingPathComponent("/claims/status"),
                                      resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "code", value: code)]

            let (data, resp) = try await URLSession.shared.data(from: comps.url!)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }

            struct St: Decodable { let device_id: String? }
            if let st = try? JSONDecoder().decode(St.self, from: data),
               let id = st.device_id, !id.isEmpty {
                return id
            }
        } catch { /* ignore */ }

        return nil
    }
    
    func loadPlants() async {
            do {
                let dtos = try await PlantAPI.list()
                let mapped = dtos.enumerated().map { i, dto in dto.toUI(number: i + 1) }
                self.plants = mapped
                if self.selectedPlantID == nil, let first = mapped.first {
                    self.selectedPlantID = first.serverId
                }
            } catch {
                self.error = "Не удалось получить список растений: \(error.localizedDescription)"
            }
        }
    
    private func requestJSON<T:Decodable>(_ type:T.Type, path:String) async throws -> T {
        let req = URLRequest(url: HPFSConfig.deviceAPBaseURL.appendingPathComponent(path), timeoutInterval: 8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300) ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func requestNoContent<T:Encodable>(path:String, body:T) async throws {
        var req = URLRequest(url: HPFSConfig.deviceAPBaseURL.appendingPathComponent(path), timeoutInterval: 8)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300) ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func sendProvision() async {
            stage = .sendWiFi
            do {
                struct ProvReq: Encodable { let ssid: String; let password: String; let claim: String }
                let body = ProvReq(ssid: selectedSSID, password: wifiPass, claim: claimCode)
                try await requestNoContent(path: HPFSConfig.configPath, body: body)

                let apSSID = "HPFS_SETUP_\(claimCode)"
                NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: apSSID)

                stage = .waitOnline
                let leftAP = await WiFiHelper.waitUntilLeft(ssid: apSSID, maxWait: 35)
                let hasNet = await WiFiHelper.waitForInternet(maxWait: 60)
                guard leftAP && hasNet else { self.error = "Подключитесь обратно к интернету."; return }

                await NetWarmup.cooldown(1.0)
                await NetWarmup.warmup(to: API.base)

                // Важно: просто стартуем авто‑поиск (Bonjour→IP + сервер)
                await MainActor.run { self.beginAutoDiscovery() }

            } catch {
                self.error = "Ошибка отправки: \(error.localizedDescription)"
            }
        }
    
    @MainActor
    func startClaimAndSetCode() async throws {
        // НИЧЕГО не просим у сервера. Пользователь ввёл "785" из SSID.
        // Просто нормализуем и проверим.
        let code = claimCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 3, code.allSatisfy(\.isNumber) else {
            throw URLError(.badURL) // или свой HPFSError
        }
    }
    
    @MainActor
    func startClaimIfEmpty() async throws {
        let cur = claimCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cur.isEmpty else { return }               // <<— ключ: уже ввёл — не трогаем
        var r = URLRequest(url: API.base.appendingPathComponent("/claims/start"))
        r.httpMethod = "POST"
        r.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = APIClient.token(.access) { r.addValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let s = try JSONDecoder().decode(StartClaimResp.self, from: data)
        self.claimCode = s.code                           // попадём сюда ТОЛЬКО если поле было пустым
    }


    func nextFromClaim() async {
        let code = claimCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { self.error = "Введите Claim Code"; return }
        guard let selectedPlantID, plants.first(where: { $0.serverId == selectedPlantID }) != nil else {
            self.error = "Выберите растение"; return
        }
        do {
            try await startClaimIfEmpty()   // ← только если поле было пустым; иначе не трогаем «785»
        } catch {
            // это не критично для флоу подключения к AP — продолжаем
            print("claim optional error:", error.localizedDescription)
        }
        await connectToAP()                 // подключаемся к HPFS_SETUP_<claimCode> (останется «785»)
    }

    func connectToAP() async {
        stage = .connectAP
        do {
            try await WiFiHelper.connect(
                ssid: "HPFS_SETUP_\(claimCode)",
                passphrase: HPFSConfig.deviceAPPassword
            )
            stage = .talkingToDevice
            try await hello()
            try await scanNetworks()
            stage = .sendWiFi
        } catch {
            self.error = "Не удалось подключиться к устройству: \(error.localizedDescription)"
        }
    }

    private func hello() async throws {
        struct HelloOK: Decodable { let ok: Bool }
        _ = try await requestJSON(HelloOK.self, path: HPFSConfig.helloPath)
    }

    func scanNetworks() async throws {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let url = HPFSConfig.deviceAPBaseURL.appendingPathComponent(HPFSConfig.scanPath)

        struct ScanObj: Decodable { let networks: [String] }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let arr: [String]
        if let obj = try? JSONDecoder().decode(ScanObj.self, from: data) { arr = obj.networks }
        else if let just = try? JSONDecoder().decode([String].self, from: data) { arr = just }
        else { arr = [] }

        let clean = Array(Set(arr.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        self.networks = clean
        if self.selectedSSID.isEmpty, let first = clean.first { self.selectedSSID = first }
    }
}

import Foundation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import Network

enum WiFiHelper {

    /// Подключаемся к AP. Если `passphrase` != nil — WPA2; иначе открытая сеть.
    static func connect(
        ssid: String,
        passphrase: String? = nil,
        isHidden: Bool = false,
        maxWait: TimeInterval = 20
    ) async throws {
        // очистим старую конфигурацию (на случай неудачных попыток)
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)

        let conf: NEHotspotConfiguration
        if let pwd = passphrase, !pwd.isEmpty {
            conf = NEHotspotConfiguration(ssid: ssid, passphrase: pwd, isWEP: false)
        } else {
            conf = NEHotspotConfiguration(ssid: ssid) // открытая сеть
        }
        conf.joinOnce = true
        if isHidden {
            // свойство называется hiddenSSID в iOS 13+, но доступ разный по SDK.
            // Используем KVC, чтобы не падать на старых SDK (безопасно игнорируется).
            conf.setValue(true, forKey: "hidden")
            conf.setValue(true, forKey: "hiddenSSID")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            NEHotspotConfigurationManager.shared.apply(conf) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }

        // ждём реального переключения на SSID + доступности 192.168.4.1:80
        let start = Date()
        while Date().timeIntervalSince(start) < maxWait {
            if let cur = await currentSSIDAsync(), cur == ssid {
                if await canOpen(host: "192.168.4.1", port: 80, timeout: 2.0) {
                    return
                }
            }
            try await Task.sleep(nanoseconds: 800_000_000) // 0.8s - пореже, меньше лог-спама
        }
        throw URLError(.timedOut)
    }
    
    

    /// Текущий SSID (нужны: Access Wi‑Fi Information + разрешение Location)
    static func currentSSID() -> String? {
        guard let ifs = CNCopySupportedInterfaces() as? [String] else { return nil }
        for ifname in ifs {
            guard
                let dict = CNCopyCurrentNetworkInfo(ifname as CFString) as? [String: AnyObject],
                let ssid = dict[kCNNetworkInfoKeySSID as String] as? String,
                !ssid.isEmpty
            else { continue }
            return ssid
        }
        return nil
    }

    // Swift 6 безопасная проверка TCP (без гонок данных)
    actor _OnceFlag { private var done = false; func trySet() -> Bool { if done { return false }; done = true; return true } }

    static func canOpen(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { cont in
            let flag = _OnceFlag()
            let params = NWParameters.tcp
            let conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: params)
            let q = DispatchQueue(label: "hpfs.tcp.check")

            conn.stateUpdateHandler = { state in
                Task {
                    switch state {
                    case .ready:
                        if await flag.trySet() { conn.cancel(); cont.resume(returning: true) }
                    case .failed, .cancelled:
                        if await flag.trySet() { cont.resume(returning: false) }
                    default: break
                    }
                }
            }
            conn.start(queue: q)
            q.asyncAfter(deadline: .now() + timeout) {
                Task {
                    if await flag.trySet() { conn.cancel(); cont.resume(returning: false) }
                }
            }
        }
    }
}

// MARK: - Bonjour/mDNS
final class BonjourWatcher: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    struct Hit { let name: String; let host: String; let port: Int }
    private var browser: NetServiceBrowser?
    private var services = [NetService]()
    private var onHit: ((Hit) -> Void)?

    func start(onHit: @escaping (Hit) -> Void) {
        stop()
        self.onHit = onHit
        let b = NetServiceBrowser()
        b.delegate = self
        b.searchForServices(ofType: "_hpfs._tcp.", inDomain: "local.")
        browser = b
    }
    func stop() {
        browser?.stop(); browser = nil
        services.forEach { $0.stop() }
        services.removeAll()
        onHit = nil
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service)
        service.resolve(withTimeout: 5)
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName else { return }
        onHit?(Hit(name: sender.name, host: host, port: sender.port))
    }
}

// MARK: - UI

struct AddHPFSDeviceView: View {
    
    @EnvironmentObject var deviceStore: DeviceStore
    @EnvironmentObject var plantStore: PlantStore
    @StateObject var vm = AddDeviceViewModel()
    
    

    var body: some View {
        ZStack {
            LinearGradient(colors: [.white, Color(.systemGreen).opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                content
                    .frame(maxWidth: 560)
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(radius: 8, y: 6)

                footer
            }
            .padding(.horizontal, 16)
        }
        .task { await vm.loadPlants() } // ← тянем список растений
        .onAppear {
            vm.onDeviceClaimed = { deviceID, plant in
                // не замыкаем EnvironmentObject внутри хранимого колбэка
                DeviceStore.shared.addClaimedDevice(id: deviceID, plant: plant)
                Task { await DeviceStore.shared.reloadFromServer() } // <-- было syncFromServer()
            }
        }
        .onChange(of: vm.stage) { new in
            print("AddDeviceView: stage -> \(new)")
        }
        .onChange(of: vm.deviceId) { id in
            print("AddDeviceView: deviceId -> \(id ?? "nil")")
        }
    }
    
    

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "leaf.arrow.circlepath")
                .font(.system(size: 44, weight: .semibold))
            Text("Добавление устройства")
                .font(.system(.title, design: .rounded).weight(.semibold))
            Text("Безопасно подключим HPFS к вашей домашней сети")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    private var content: some View {
        switch vm.stage {

        case .enterClaim:
            EnterClaimView(
                claimCode: $vm.claimCode,
                onNext: { Task { await vm.nextFromClaim() } }
            )
            .environmentObject(vm) // ← добавить

        case .connectAP:
            ProgressBlock(title: "Подключаемся к устройству",
                          subtitle: "HPFS_SETUP_\(vm.claimCode)")

        case .talkingToDevice:
            ProgressBlock(title: "Связь с устройством",
                          subtitle: "Проверяем /hello и получаем список сетей")

        case .sendWiFi:
            ChooseWiFiView(
                networks: vm.networks,
                selectedHomeSSID: $vm.selectedSSID,
                password: $vm.wifiPass,
                onSend: { Task { await vm.sendProvision() } }
            )

        case .waitOnline:
            VStack(spacing: 12) {
                ProgressBlock(title: "Ожидаем устройство в сети",
                              subtitle: "Подтверждаем клейм на сервере")

                Button {
                    Task { await vm.forceAttachNow() }
                } label: {
                    Label("Уже вижу устройство локально", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
            }

        case .selectPlant(let deviceId):
            VStack(spacing: 12) {
                Text("Устройство найдено: \(deviceId)")
                Text("Дальше — выбор растения и привязка.")
                // TODO: перейти к экрану выбора растения
                Button("Готово") { vm.stage = .done }
                    .buttonStyle(.borderedProminent)
            }

        case .done:
            VStack(spacing: 12) {
                Label("Готово!", systemImage: "checkmark.seal.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                Text("Устройство добавлено и готово к работе.")
                Button("Закрыть") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Подсказка: точка устройства называется")
                .font(.footnote).foregroundStyle(.secondary)
            Text("HPFS_SETUP_<Ваш Claim Code>")
                .font(.footnote.monospaced()).foregroundStyle(.secondary)
        }
        .onDisappear { vm.stopAutoDiscovery() }
    }
}

// MARK: - Subviews

struct EnterClaimView: View {
    @Binding var claimCode: String

    // 👇 добавим связывание с VM через EnvironmentObject, чтобы не плодить пропсы,
    // либо пробрось selectedPlantID/plants через параметры — на твой вкус
    @EnvironmentObject var vm: AddDeviceViewModel

    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Выбор растения
            if vm.plants.isEmpty {
                HStack {
                    ProgressView()
                    Text("Загружаем растения…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Растение", selection: $vm.selectedPlantID) {
                    ForEach(vm.plants) { p in
                        Text(p.name).tag(Optional(p.serverId))
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("Claim Code", text: $claimCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .font(.title3.monospaced())
                .submitLabel(.go)
                .onSubmit(onNext)

            Button {
                onNext()
            } label: {
                Label("Далее", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(claimCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.selectedPlantID == nil)

            VStack(spacing: 6) {
                Text("Мы подключимся к точке устройства и запросим список доступных Wi‑Fi сетей.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Пароль от домашнего Wi‑Fi никогда не покидает ваше устройство и передаётся напрямую на HPFS по локальной сети.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct ChooseWiFiView: View {
    let networks: [String]
    @Binding var selectedHomeSSID: String
    @Binding var password: String
    var onSend: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Подключение к домашней сети")
                .font(.title3.bold())

            // Список сетей, отсканированных устройством
            if networks.isEmpty {
                VStack(spacing: 8) {
                    ProgressView("Ищем сети…")
                    Text("Если список не появился, вернитесь назад и попробуйте ещё раз.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Picker("Сеть Wi‑Fi", selection: $selectedHomeSSID) {
                    ForEach(networks, id: \.self) { ssid in
                        Text(ssid).tag(ssid)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            SecureField("Пароль Wi-Fi", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)

            Button {
                onSend()
            } label: {
                Label("Подключить", systemImage: "wifi.router.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedHomeSSID.isEmpty || password.isEmpty)

            Text("Список сетей предоставляет само устройство.\niOS не позволяет приложениям перечислять SSID напрямую.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct ProgressBlock: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import Network

extension WiFiHelper {
    // 1) Получаем текущий SSID: сперва через fetchCurrent (для сетей, подключённых через NEHotspotConfiguration),
    // затем fallback через CaptiveNetwork (нужны Access Wi‑Fi Info + Location).
    static func currentSSIDAsync() async -> String? {
        await withCheckedContinuation { cont in
            NEHotspotNetwork.fetchCurrent { net in
                if let ssid = net?.ssid, !ssid.isEmpty {
                    cont.resume(returning: ssid)
                } else {
                    cont.resume(returning: currentSSIDViaCaptive())
                }
            }
        }
    }

    private static func currentSSIDViaCaptive() -> String? {
        guard let ifs = CNCopySupportedInterfaces() as? [String] else { return nil }
        for ifname in ifs {
            guard
                let dict = CNCopyCurrentNetworkInfo(ifname as CFString) as? [String: AnyObject],
                let ssid = dict[kCNNetworkInfoKeySSID as String] as? String,
                !ssid.isEmpty
            else { continue }
            return ssid
        }
        return nil
    }

    // 2) Ждём, пока устройство ВЫЙДЕТ из указанного SSID (т.е. сменится на любой другой или станет nil).
    static func waitUntilLeft(ssid target: String, maxWait: TimeInterval = 30) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < maxWait {
            if let cur = await currentSSIDAsync() {
                if cur != target { return true }
            } else {
                // нет Wi‑Fi — тоже значит, что вышли из AP
                return true
            }
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s чтобы не спамить nehelper
        }
        return false
    }

    // (у тебя уже есть) Swift 6‑safe ожидание интернета через NWPathMonitor
    actor _Once { private var used = false; func trySet() -> Bool { if used { return false }; used = true; return true } }

    static func waitForInternet(maxWait: TimeInterval = 45) async -> Bool {
        await withCheckedContinuation { cont in
            let mon = NWPathMonitor()
            let q = DispatchQueue(label: "hpfs.net.wait", qos: .utility)
            let once = _Once()

            mon.pathUpdateHandler = { path in
                Task {
                    if path.status == .satisfied, await once.trySet() {
                        mon.cancel()
                        cont.resume(returning: true)
                    }
                }
            }
            mon.start(queue: q)
            q.asyncAfter(deadline: .now() + maxWait) {
                Task {
                    if await once.trySet() {
                        mon.cancel()
                        cont.resume(returning: false)
                    }
                }
            }
        }
    }
}

enum NetWarmup {
    static func cooldown(_ seconds: Double = 1.5) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    static func warmup(to url: URL, attempts: Int = 3) async {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        cfg.allowsCellularAccess = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.timeoutIntervalForRequest = 6
        let sess = URLSession(configuration: cfg)

        for i in 0..<attempts {
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            do {
                _ = try await sess.data(for: req)
                return
            } catch {
                // эксп. бэкофф
                let backoff = min(1.0 * pow(1.6, Double(i)), 3.0)
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }
    }
}

private struct AttachReq: Encodable {
    let device_id: String
    let plant_id: Int?
    let claim: String
}

#Preview{
    AddHPFSDeviceView()
}
