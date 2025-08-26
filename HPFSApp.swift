//
//  HPFSApp.swift
//  HPFS
//
//  Created by Роман on 20.04.2025.
//

import SwiftUI

@main
struct HPFSApp: App {
    
    init() {
            APIClient.accessTokenProvider = { KeychainHelper.loadToken(for: "hpfs_access") }
        }
    
    @StateObject private var session = Session()
    @StateObject private var plantStore  = PlantStore.shared
    @StateObject private var deviceStore = DeviceStore.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Group {
                    if session.isAuthenticated {
                        ContentView()
                            .environmentObject(session)
                    } else {
                        WelcomeView()
                            .environmentObject(session)
                    }
                }
                // если вдруг вернёмся в приложение из бэкграунда — перепроверим
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    session.refreshGateRecheck()
                }
            }
            .environmentObject(plantStore)
            .environmentObject(deviceStore)
        }
    }
}

