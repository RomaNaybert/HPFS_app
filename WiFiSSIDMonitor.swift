//
//  WiFiSSIDMonitor.swift
//  HPFS
//
//  Created by Роман on 19.08.2025.
//

// WiFiSSIDMonitor.swift
import Foundation
import Combine
import CoreLocation
import SystemConfiguration.CaptiveNetwork
import Network
import NetworkExtension
import UIKit

@MainActor
final class WiFiSSIDMonitor: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var currentSSID: String? = nil
    @Published private(set) var isInSetupAP: Bool = false

    private let lm = CLLocationManager()
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let pathQueue = DispatchQueue(label: "wifi.path.monitor")
    private var tickTimer: AnyCancellable?
    private var appActiveCancellable: AnyCancellable?

    /// Если ты сам подключал к сети через NEHotspotConfigurationManager — укажи здесь SSID.
    /// Тогда попробуем fetchCurrent, иначе сразу пойдём в CNCopyCurrentNetworkInfo.
    var lastConfiguredSSIDByApp: String?

    override init() {
        super.init()
        lm.delegate = self

        // следим за активностью приложения
        appActiveCancellable = NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))
            .sink { [weak self] _ in self?.kick() }

        // мониторим наличие Wi‑Fi интерфейса
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in self?.kick() }
        }
        pathMonitor.start(queue: pathQueue)

        // просим разрешение location (для CNCopyCurrentNetworkInfo)
        lm.requestWhenInUseAuthorization()

        // «тихий» таймер, чтобы не шуметь (1.2 сек)
        tickTimer = Timer.publish(every: 1.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.kick() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        kick()
    }

    private func kick() {
        guard UIApplication.shared.applicationState == .active else { return }
        let status = lm.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        fetchSSID()
    }

    private func fetchSSID() {
        // 1) Если сеть конфигурировали мы сами — пробуем NEHotspotNetwork.fetchCurrent
        if lastConfiguredSSIDByApp != nil {
            NEHotspotNetwork.fetchCurrent { [weak self] net in
                Task { @MainActor in
                    if let ssid = net?.ssid, !ssid.isEmpty {
                        self?.apply(ssid: ssid)
                    } else {
                        // 2) Fallback — системный API
                        self?.apply(ssid: Self.copySSIDViaCaptive())
                    }
                }
            }
        } else {
            // сразу fallback
            apply(ssid: Self.copySSIDViaCaptive())
        }
    }

    private func apply(ssid: String?) {
        // публикем только при изменении (removeDuplicates вручную)
        if currentSSID != ssid {
            currentSSID = ssid
        }
        let flag = ssid?.hasPrefix("HPFS_SETUP_") ?? false
        if isInSetupAP != flag {
            isInSetupAP = flag
        }
    }

    private static func copySSIDViaCaptive() -> String? {
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
}
