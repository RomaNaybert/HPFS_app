// DeviceDiscovery.swift
import Foundation
import Network

enum DiscoveryEvent: Equatable {
    case started(String)
    case bonjourFound(name: String, ip: String, port: Int)
    case helloOK(deviceID: String)
    case serverSeen(deviceID: String)
    case finished(deviceID: String)
    case timeout
    case cancelled
    case error(String)
}

/// Bonjour → получаем IPv4 адрес сервиса _hpfs._tcp.
final class BonjourToIP: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var onHit: ((String, String, Int) -> Void)?

    func start(onHit: @escaping (String, String, Int) -> Void) {
        self.onHit = onHit
        browser.delegate = self
        browser.searchForServices(ofType: "_hpfs._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        services.forEach { $0.stop() }
        services.removeAll()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service)
        service.resolve(withTimeout: 5)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses, let ip = Self.ipv4String(from: addresses) else { return }
        onHit?(sender.name, ip, sender.port)
    }

    private static func ipv4String(from addresses: [Data]) -> String? {
        var result: String?
        for data in addresses {
            data.withUnsafeBytes { raw in
                guard raw.count >= MemoryLayout<sockaddr>.size else { return }
                let sa = raw.bindMemory(to: sockaddr.self)
                if sa[0].sa_family == sa_family_t(AF_INET) {
                    let sin = raw.bindMemory(to: sockaddr_in.self)
                    var addr = sin[0].sin_addr
                    var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
                    if let s = String(validatingUTF8: buf) { result = s }
                }
            }
            if result != nil { break }
        }
        return result
    }
}

final class DeviceDiscovery {
    private var cancelled = false
    func cancel() { cancelled = true }

    /// Запуск: гонка из трёх каналов — Bonjour(IP→/hello), /hello по mDNS (если вдруг сработает), и сервер.
    func run(code: String,
             overallTimeout: TimeInterval = 60,
             localWindow: TimeInterval = 12,
             api: @escaping (_ path: String, _ q: [String:String]) async throws -> Data,
             parseServerSeen: @escaping (Data) throws -> String?) -> AsyncStream<DiscoveryEvent> {

        AsyncStream { continuation in
            continuation.yield(.started(code))

            let deadline = Date().addingTimeInterval(overallTimeout)

            // Канал A: Bonjour -> IP -> /hello по IP (без .local)
            let bonjour = BonjourToIP()
            var bonjourHit = false
            bonjour.start { name, ip, port in
                if self.cancelled { return }
                bonjourHit = true
                continuation.yield(.bonjourFound(name: name, ip: ip, port: port))
                Task {
                    let url = URL(string: "http://\(ip):\(max(port, 80))/hello")!
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 2.8
                    if let (id, ok) = await Self.tryHello(req: req, fallback: "hpfs-\(code)"), ok {
                        if self.cancelled { return }
                        continuation.yield(.helloOK(deviceID: id))
                        continuation.yield(.finished(deviceID: id))
                        bonjour.stop()
                        continuation.finish()
                    }
                }
            }

            // Канал B: mDNS .local (best-effort первые N секунд)
            Task {
                let start = Date()
                while Date() < start.addingTimeInterval(localWindow) && !self.cancelled {
                    let base = URL(string: "http://hpfs-\(code).local/hello")!
                    var req = URLRequest(url: base)
                    req.timeoutInterval = 2.0
                    if let (id, ok) = await Self.tryHello(req: req, fallback: "hpfs-\(code)"), ok {
                        if self.cancelled { return }
                        continuation.yield(.helloOK(deviceID: id))
                        continuation.yield(.finished(deviceID: id))
                        bonjour.stop()
                        continuation.finish()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 600_000_000)
                }
            }

            // Канал C: сервер (весь таймаут)
            Task {
                var attempt = 0
                while Date() < deadline && !self.cancelled {
                    // сначала точечная проверка по device_id
                    do {
                        let d1 = try await api("/devices", ["device_id": "hpfs-\(code)"])
                        if let id = (try? parseServerSeen(d1)) ?? nil, !id.isEmpty {
                            if self.cancelled { return }
                            continuation.yield(.serverSeen(deviceID: id))
                            continuation.yield(.finished(deviceID: id))
                            bonjour.stop()
                            continuation.finish()
                            return
                        }
                    } catch { /* ignore */ }

                    // затем — claims/status
                    do {
                        let d2 = try await api("/claims/status", ["code": code])
                        if let id = try? parseServerSeen(d2), !id.isEmpty {
                            if self.cancelled { return }
                            continuation.yield(.serverSeen(deviceID: id))
                            continuation.yield(.finished(deviceID: id))
                            bonjour.stop()
                            continuation.finish()
                            return
                        }
                    } catch { /* ignore */ }

                    attempt += 1
                    let delay = min(0.7 * pow(1.4, Double(attempt)), 2.0)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                if !self.cancelled && !bonjourHit {
                    continuation.yield(.timeout)
                    bonjour.stop()
                    continuation.finish()
                }
            }

            // Жёсткий overall timeout защёлкивает поток
            Task {
                try? await Task.sleep(nanoseconds: UInt64(overallTimeout * 1_000_000_000))
                if !self.cancelled {
                    continuation.yield(.timeout)
                    bonjour.stop()
                    continuation.finish()
                }
            }
        }
    }

    private static func tryHello(req: URLRequest, fallback: String) async -> (String, Bool)? {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            struct Hello: Decodable { let device_id: String? }
            if let ok = try? JSONDecoder().decode(Hello.self, from: data), let id = ok.device_id, !id.isEmpty {
                return (id, true)
            } else {
                return (fallback, true)
            }
        } catch {
            return nil
        }
    }
}
