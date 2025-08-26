//
//  NetworkLayer.swift
//  HPFS
//
//  Created by Роман on 09.08.2025.
//

import Foundation
import Security
import Combine
import CoreBluetooth

struct API {
    static let base = URL(string: "https://api.hpfs.ru")! // твой домен
}

enum APIError: Error, LocalizedError {
    case badResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .badResponse: return "Сервер недоступен"
        case .server(let msg): return msg
        }
    }
}

func jwtExpiration(_ token: String) -> Date? {
    let parts = token.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    func base64urlDecode(_ s: Substring) -> Data? {
        var str = String(s)
        str = str.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - (str.count % 4)
        if pad < 4 { str += String(repeating: "=", count: pad) }
        return Data(base64Encoded: str)
    }
    guard let payloadData = base64urlDecode(parts[1]),
          let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String:Any],
          let exp = obj["exp"] as? Double else { return nil }
    return Date(timeIntervalSince1970: exp)
}

func isJWTValidNow(_ token: String) -> Bool {
    guard let exp = jwtExpiration(token) else { return false }
    return exp > Date()
}

@MainActor
final class AuthVM: ObservableObject {
    @Published var isLoggingIn = false
    @Published var email = ""
    @Published var password = ""
    @Published var code = ""
    @Published var stage: Stage = .enterEmailPass
    @Published var message: String?
    @Published var isStarting = false
    @Published var isVerifying = false
    @Published var isResending = false
    
    let plantStore = PlantStore.shared

    var session: Session?
    
    enum Stage { case enterEmailPass, enterCode, done }
    
    private func request<T: Encodable>(_ path: String, body: T) async throws -> [String:Any] {
        var req = URLRequest(url: API.base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any] ?? [:]
        if http.statusCode >= 200 && http.statusCode < 300 {
            return json
        } else {
            let msg = (json["error"] as? String) ?? "Ошибка"
            throw APIError.server(msg)
        }
    }
    
    func startRegistration() async {
        message = nil
        isStarting = true
        defer { isStarting = false }
        do {
            _ = try await request("/auth/register/start", body: ["email": email, "password": password])
            stage = .enterCode
        } catch {
            message = error.localizedDescription
        }
    }
    
    func verifyCode() async {
        message = nil
        isVerifying = true
        defer { isVerifying = false }
        do {
            let json = try await request("/auth/register/verify", body: ["email": email, "code": code])
            if let access = json["access"] as? String, let refresh = json["refresh"] as? String {
                        session?.signIn(access: access, refresh: refresh) // ← обновим сессию
                        stage = .done
                        Auth.shared.jwt    = access
                        Auth.shared.userId = decodeUserId(fromJWT: access)
                    Task { await plantStore.fetchAll() }
                    } else {
                message = "Не получили токены"
            }
        } catch {
            message = error.localizedDescription
        }
    }
    
    func resend() async {
        message = nil
        isResending = true
        defer { isResending = false }
        do {
            _ = try await request("/auth/resend", body: ["email": email])
            message = "Код отправлен повторно"
        } catch {
            message = error.localizedDescription
        }
    }
    func login() async {
        message = nil
        isLoggingIn = true
        defer { isLoggingIn = false }
        do {
            let json = try await request("/auth/login", body: ["email": email, "password": password])
            if let access = json["access"] as? String, let refresh = json["refresh"] as? String {
                        session?.signIn(access: access, refresh: refresh) // ← обновим сессию
                        stage = .done
                        Task { await plantStore.fetchAll() }
                        message = nil
                    } else {
                message = "Не получили токены"
            }
        } catch {
            message = error.localizedDescription
        }
    }
}

@MainActor
final class Session: ObservableObject {
    @Published var isAuthenticated: Bool = false

    init() {
        // читаем refresh из Ключницы и решаем
        if let refresh = KeychainHelper.loadToken(for: "hpfs_refresh"), isJWTValidNow(refresh) {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }

    func signIn(access: String, refresh: String) {
        do {
            try KeychainHelper.save(token: access, for: "hpfs_access")
            try KeychainHelper.save(token: refresh, for: "hpfs_refresh")
            isAuthenticated = true
            // синхронизируем вспомогательный сервис
            Auth.shared.jwt = access
            Auth.shared.userId = decodeUserId(fromJWT: access)
        } catch {
            isAuthenticated = false
        }
    }

    func signOut() {
        KeychainHelper.deleteToken(for: "hpfs_access")
        KeychainHelper.deleteToken(for: "hpfs_refresh")
        isAuthenticated = false
    }

    func refreshGateRecheck() {
        if let refresh = KeychainHelper.loadToken(for: "hpfs_refresh"), isJWTValidNow(refresh) {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }
}


enum KeychainHelper {
    static func save(token: String, for key: String) throws {
            let data = Data(token.utf8)

            let baseQuery: [String:Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "hpfs.auth",
                kSecAttrAccount as String: key
            ]

            // Сначала стираем прошлую запись
            SecItemDelete(baseQuery as CFDictionary)

            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data

            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // На всякий — обновим
                let attrs = [kSecValueData as String: data]
                let up = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
                guard up == errSecSuccess else { throw NSError(domain: "kc", code: Int(up)) }
            } else if status != errSecSuccess {
                throw NSError(domain: "kc", code: Int(status))
            }
        }

    
    static func loadToken(for key: String) -> String? {
            let query: [String:Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "hpfs.auth",
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess,
                  let data = item as? Data,
                  let token = String(data: data, encoding: .utf8) else { return nil }
            return token
        }

        static func deleteToken(for key: String) {
            let query: [String:Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "hpfs.auth",
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
}

import Foundation
import Security
import SwiftUICore

struct PlantDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let location: String
    let avatar: Int
    let humidity: Int
    let temperature: Int
}

struct CreatePlantRequest: Codable {
    let name: String
    let location: String
    let avatar: Int
    let humidity: Int
    let temperature: Int
}

enum HTTPMethod: String { case GET, POST, DELETE }

enum AuthTokenType { case access, refresh }

struct APIClient {
    
    static func getJSON<T: Decodable>(_ path: String,
                                      query: [String: String] = [:],
                                      as type: T.Type = T.self) async throws -> T {
        guard var comps = URLComponents(url: API.base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw HPFSError.badURL
        }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw HPFSError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIClient.token(.access) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw HPFSError.badURL }
        guard (200...299).contains(http.statusCode) else { throw HPFSError.http(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private static let session: URLSession = {
            let cfg = URLSessionConfiguration.default
            cfg.waitsForConnectivity = true
            cfg.allowsCellularAccess = true
            cfg.allowsExpensiveNetworkAccess = true
            cfg.allowsConstrainedNetworkAccess = true
            cfg.timeoutIntervalForRequest = 15
            cfg.timeoutIntervalForResource = 30
            return URLSession(configuration: cfg)
        }()

        // …дальше поменяй URLSession.shared на session:
        static func request<T: Decodable>(
            _ method: HTTPMethod = .GET,
            path: String,
            query: [String:String?] = [:],
            as type: T.Type
        ) async throws -> T {
            var comps = URLComponents(url: API.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
            if !query.isEmpty {
                comps.queryItems = query.compactMap { URLQueryItem(name: $0.key, value: $0.value) }
            }
            var req = URLRequest(url: comps.url!, timeoutInterval: 15)
            req.httpMethod = method.rawValue
            if let token = accessTokenProvider?() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

            let (data, resp) = try await session.data(for: req) // <-- здесь
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode(T.self, from: data)
        }
    
    static var accessTokenProvider: (() -> String?)? = nil
    
    static func token(_ type: AuthTokenType) -> String? {
        switch type {
        case .access:  return KeychainHelper.loadToken(for: "hpfs_access")
        case .refresh: return KeychainHelper.loadToken(for: "hpfs_refresh")
        }
    }

    static func authorizedRequest(path: String,
                                  method: HTTPMethod,
                                  body: Data? = nil) throws -> URLRequest {
        var req = URLRequest(url: API.base.appendingPathComponent(path))
        req.httpMethod = method.rawValue
        if let body = body {
            req.httpBody = body
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        guard let access = token(.access) else { throw APIError.server("Нет access токена") }
        req.addValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        return req
    }

    /// универсальный вызов с авто-рефрешем на 401
    static func call<T: Decodable>(_ type: T.Type,
                                   path: String,
                                   method: HTTPMethod = .GET,
                                   body: Data? = nil) async throws -> T {
        do {
            var req = try authorizedRequest(path: path, method: method, body: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                // попробовать рефреш
                try await refreshTokens()
                req = try authorizedRequest(path: path, method: method, body: body)
                let (data2, resp2) = try await URLSession.shared.data(for: req)
                try Self.throwIfServerError(resp2, data2)
                return try JSONDecoder().decode(T.self, from: data2)
            } else {
                try Self.throwIfServerError(resp, data)
                return try JSONDecoder().decode(T.self, from: data)
            }
        } catch {
            throw error
        }
    }

    static func callNoContent(path: String,
                              method: HTTPMethod = .DELETE) async throws {
        var req = try authorizedRequest(path: path, method: method, body: nil)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            try await refreshTokens()
            req = try authorizedRequest(path: path, method: method, body: nil)
            let (data2, resp2) = try await URLSession.shared.data(for: req)
            try Self.throwIfServerError(resp2, data2)
            return
        } else {
            try Self.throwIfServerError(resp, data)
        }
    }

    private static func throwIfServerError(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }
        if !(200..<300).contains(http.statusCode) {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any]
            let msg = (json?["error"] as? String) ?? "Ошибка"
            throw APIError.server(msg)
        }
    }
    
    
    
    static func refreshTokens() async throws {
        guard let refresh = token(.refresh) else { throw APIError.server("Нет refresh токена") }

        var req = URLRequest(url: API.base.appendingPathComponent("/auth/refresh"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["refresh": refresh])

        let (data, resp) = try await URLSession.shared.data(for: req)
        try throwIfServerError(resp, data)

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any]
        guard let access = json?["access"] as? String,
              let newRefresh = json?["refresh"] as? String else {
            throw APIError.server("Не получили новые токены")
        }

        try KeychainHelper.save(token: access, for: "hpfs_access")
        try KeychainHelper.save(token: newRefresh, for: "hpfs_refresh")

        // ↓↓↓ безопасно обновим наблюдаемый стейт
        await MainActor.run {
            Auth.shared.jwt = access
            Auth.shared.userId = decodeUserId(fromJWT: access)
        }
    }
    
}


struct EmptyDTO: Codable {}


enum PlantAPI {
    static func list() async throws -> [PlantDTO] {
        try await APIClient.call([PlantDTO].self, path: "/plants")
    }
    static func create(_ req: CreatePlantRequest) async throws -> Int {
        let body = try JSONEncoder().encode(req)
        struct Created: Decodable { let id: Int }
        let created = try await APIClient.call(Created.self, path: "/plants", method: .POST, body: body)
        return created.id
    }
    static func delete(id: Int) async throws {
        try await APIClient.callNoContent(path: "/plants/\(id)", method: .DELETE)
    }
}


extension PlantDTO {
    func toUI(number: Int) -> Plant {
        let colorCard: Color = {
            if number % 2 != 0 && number % 3 != 0 { return Color("ColorCardLightGreen") }
            else if number % 2 == 0 && number % 4 != 0 { return Color(.colorCardTeaGreen) }
            else if number % 3 == 0 { return Color(.white) }
            else { return Color(.colorCardPastelGreen) }
        }()
        let colorCardCircle: Color = (number % 3 == 0) ? Color("ColorCardPastelGreen") : Color(.colorDarkGrey)
        let colorNumber: Color = (number % 3 == 0) ? Color(.colorDarkGrey) : .white

        return Plant(
            serverId: id,
            name: name,
            location: location,
            colorCard: colorCard,
            colorNumber: colorNumber,
            colorCardCitcle: colorCardCircle,
            humidity: humidity,
            temperature: temperature
        )
    }
}




// MARK: - Claim API models
struct StartClaimResp: Codable {
    let code: String
    let ttl_sec: Int
}

struct ClaimStatus: Codable {
    let code: String?
    let user_id: Int?
    let reserved_at: Int?
    let consumed_at: Int?
    let device_id: String?
    let expired: Bool?
}

enum HPFSError: Error {
    case badURL
    case http(Int)
    case decoding(Error)
    case timeout(String)
}


import Foundation
import CoreBluetooth
import Combine

final class SetupPresenceMonitor: NSObject, ObservableObject {
    @Published private(set) var isSetupPeripheralNearby = false

    private var central: CBCentralManager!
    private var lastSeenAt: Date?
    private var timer: Timer?

    // Настрой под себя
    private let namePrefix = "HPFS_SETUP"    // или "HPFS-"
    private let serviceUUID = CBUUID(string: "F00D") // если добавишь сервис

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)

        // таймер гасит флаг, если реклама пропала
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let t = lastSeenAt, Date().timeIntervalSince(t) < 5 {
                if self.isSetupPeripheralNearby == false { self.isSetupPeripheralNearby = true }
            } else {
                if self.isSetupPeripheralNearby == true { self.isSetupPeripheralNearby = false }
            }
        }
    }

    deinit { timer?.invalidate(); central?.stopScan() }

    private func startScan() {
        guard central.state == .poweredOn else { return }
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        // Если есть сервис — фильтруем по нему (лучше экономия батареи)
        central.scanForPeripherals(withServices: [serviceUUID], options: options)
        // Если сервиса нет, можно сканировать без него и фильтровать по имени
        // central.scanForPeripherals(withServices: nil, options: options)
    }
}

extension SetupPresenceMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: startScan()
        default:
            central.stopScan()
            isSetupPeripheralNearby = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        // Фильтр по имени (если нет сервисов)
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
           name.hasPrefix(namePrefix) {
            lastSeenAt = Date()
            return
        }
        // Если скан по сервису — любой хит значит устройство найдено
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           services.contains(serviceUUID) {
            lastSeenAt = Date()
        }
    }
}


import Foundation

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    private init() {}

    // заполняй при логине
    @Published var jwt: String?
    @Published var userId: Int?
}

// Удобный псевдоним, чтобы не переписывать везде код
enum Auth {
    @MainActor static var shared: AuthService { AuthService.shared }
}

// Совместимо с текущим JSON сервера
struct ServerDeviceRow: Codable {
    let device_id: String
    let firmware_version: String?
    let last_seen_at: Int?
    let online: Int?
    let owner_id: Int?
    let plant_id: Int?
    let humidity: Int?
    let water: Int?
    let temp: Int?
}

enum DeviceAPI {
    static func list() async throws -> [ServerDeviceRow] {
        try await APIClient.call([ServerDeviceRow].self, path: "/devices")
    }

    struct AttachReq: Codable { let device_id: String; let plant_id: Int?; let claim: String }
    static func attach(deviceID: String, plantId: Int?, claim: String) async throws {
        let body = try JSONEncoder().encode(AttachReq(device_id: deviceID, plant_id: plantId, claim: claim))
        struct Ok: Decodable { let ok: Bool }
        _ = try await APIClient.call(Ok.self, path: "/devices/attach", method: .POST, body: body)
    }
}

// MARK: - JWT decode helpers (file-scope)

func decodeUserId(fromJWT token: String) -> Int? {
    let parts = token.split(separator: ".")
    guard parts.count >= 2,
          let data = Data(base64URLEncoded: String(parts[1])),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else { return nil }

    if let uid = obj["user_id"] as? Int { return uid }
    if let sub = obj["sub"] as? String, let uid = Int(sub) { return uid }
    if let sub = obj["sub"] as? Int { return sub }
    return nil
}

extension Data {
    /// Base64URL → Data
    init?(base64URLEncoded str: String) {
        var s = str.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }
}

struct TelemetryLatestDTO: Decodable {
    let ts: Int?
    let humidity: Int?
    let temperature: Double?
    let water: String?
    let online: Bool?
}

struct RelayLastDTO: Decodable {
    let state: String?   // "on" | "off" | nil (если не было команд)
    let version: Int
    let updated_at: Int?
}
