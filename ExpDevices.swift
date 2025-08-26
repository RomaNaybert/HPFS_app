//
//  ExpDevices.swift
//  HPFS
//
//  Created by Роман on 07.08.2025.
//

import SwiftUI

struct WiFiCredentialsView: View {
    @State private var ssid = ""
    @State private var password = ""
    @State private var isSending = false
    @State private var resultMessage = ""
    @State private var humidity: String = "-"
    @State private var water: String = "-"


    var body: some View {
        VStack(spacing: 20) {
            TextField("Название Wi-Fi сети", text: $ssid)
                .textFieldStyle(.roundedBorder)

            SecureField("Пароль от Wi-Fi", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Отправить") {
                sendCredentials()
                fetchSensorData()
            }
            .buttonStyle(.borderedProminent)

            if isSending {
                ProgressView("Отправка...")
            }

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .foregroundColor(.gray)
            }
            if !humidity.isEmpty || !water.isEmpty {
                VStack(spacing: 10) {
                    HStack {
                        Text("💧 Влажность:")
                        Spacer()
                        Text(humidity)
                            .bold()
                    }
                    HStack {
                        Text("🌊 Вода:")
                        Spacer()
                        Text(water)
                            .bold()
                    }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)
                .onAppear {
                    fetchSensorData()
                }

            }

        }
        .padding()
        .navigationTitle("Подключение к Wi-Fi")
        .onAppear {
            fetchSensorData()
        }

    }

    func sendCredentials() {
        guard let url = URL(string: "http://192.168.4.1/provision") else { return }

        let payload: [String: String] = [
            "ssid": ssid,
            "password": password
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        isSending = true
        resultMessage = ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSending = false
                if let error = error {
                    resultMessage = "Ошибка: \(error.localizedDescription)"
                } else {
                    resultMessage = "✅ Данные отправлены!"
                }
            }
        }.resume()
    }
    func fetchSensorData() {
        guard let url = URL(string: "http://195.133.25.176:5000/data") else { return } // ← поменяй на IP своего ESP

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer hpf_secret_token", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    humidity = "\(json["humidity"] ?? "-") %"
                    water = (json["water"] as? String) == "yes" ? "Есть вода" : "Нет воды"
                } else {
                    humidity = "-"
                    water = "-"
                }
            }
        }.resume()
    }

}


import SwiftUI
import NetworkExtension

struct AccessPointListView: View {
    @State private var isConnecting = false
    @State private var showNext = false
    @State private var selectedAP = ""
    
    // Условный список AP-шек (эмуляция, т.к. iOS не даст получить их напрямую)
    let fakeAPs = ["HPFS_SETUP_1234", "HPFS_SETUP_5678", "Cafe_FreeWiFi"]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(fakeAPs.filter { $0.hasPrefix("HPFS_SETUP_") }, id: \.self) { ap in
                    Button(action: {
                        selectedAP = ap
                        connectToAccessPoint(ssid: ap)
                    }) {
                        Text(ap)
                    }
                }
            }
            .overlay {
                if isConnecting {
                    ProgressView("Подключение...")
                }
            }
            .navigationTitle("Выбор устройства")
            .navigationDestination(isPresented: $showNext) {
                WiFiCredentialsView()
            }
        }
    }
    
    func connectToAccessPoint(ssid: String) {
        isConnecting = true
        
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let config = NEHotspotConfiguration(ssid: ssid, passphrase: "setup1234", isWEP: false)
            config.joinOnce = false
            
            NEHotspotConfigurationManager.shared.apply(config) { error in
                DispatchQueue.main.async {
                    isConnecting = false
                    
                    if let error = error {
                        print("❌ Ошибка подключения: \(error.localizedDescription)")
//                        resultMessage = "Ошибка: \(error.localizedDescription)"
                    } else {
                        print("✅ Подключено к \(ssid)")
                        showNext = true
                    }
                }
            }
        }
    }
}
