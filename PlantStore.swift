//
//  PlantStore.swift
//  HPFS
//
//  Created by Роман on 18.05.2025.
//

import Foundation
import SwiftUI

@MainActor
class PlantStore: ObservableObject {
    static let shared = PlantStore()
    
    @Published var plants: [Plant] = []
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var error: String?
    
    // MARK: - Cache
       private var cacheURL: URL = {
           let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
           let url = dir.appendingPathComponent("plants_cache.json")
           // на всякий случай создадим директорию
           try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
           return url
       }()
    
    func loadFromCache() {
            guard let data = try? Data(contentsOf: cacheURL) else { return }
            guard let dtos = try? JSONDecoder().decode([PlantDTO].self, from: data) else { return }
            var ui: [Plant] = []
            for (idx, dto) in dtos.enumerated() { ui.append(dto.toUI(number: idx + 1)) }
            self.plants = ui
        }

        private func saveCache(_ dtos: [PlantDTO]) {
            do {
                let data = try JSONEncoder().encode(dtos)
                try data.write(to: cacheURL, options: [.atomic])   // атомарная запись — безопасно
            } catch {
                print("cache save error:", error)
            }
        }
    
    /// Загружает все растения пользователя из API
    func fetchAll() async {
        guard KeychainHelper.loadToken(for: "hpfs_access") != nil else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let dtos = try await PlantAPI.list()
            // UI
            var ui: [Plant] = []
            for (idx, dto) in dtos.enumerated() { ui.append(dto.toUI(number: idx + 1)) }
            self.plants = ui
            // Cache
            saveCache(dtos)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Создаёт растение на сервере и добавляет в список (оптимистично)
    func create(name: String, location: String, avatar: Int, humidity: Int, temperature: Int) async -> Bool {
            error = nil
            isCreating = true
            defer { isCreating = false }
            do {
                _ = try await PlantAPI.create(.init(name: name, location: location, avatar: avatar, humidity: humidity, temperature: temperature))
                // Перегружаем с сервера (и кэш автоматически обновится)
                await fetchAll()
                return true
            } catch {
                self.error = error.localizedDescription
                return false
            }
        }

    /// Удаляет растение на сервере и в UI
    func delete(serverId: Int) async {
            error = nil
            // оптимистичное удаление: сначала выкинем из UI
            let oldPlants = plants
            if let idx = plants.firstIndex(where: { $0.serverId == serverId }) {
                plants.remove(at: idx)
            }
            // попытаемся ударить сервер
            do {
                try await PlantAPI.delete(id: serverId)
                // сервер ок — обновим кэш из текущего UI (пересоберём DTOs)
                let dtos = plants.map { p in
                    PlantDTO(id: p.serverId, name: p.name, location: p.location, avatar: 0, humidity: p.humidity, temperature: p.temperature)
                }
                saveCache(dtos)
            } catch {
                // откатим UI, покажем ошибку
                self.plants = oldPlants
                self.error = error.localizedDescription
            }
        }
}
