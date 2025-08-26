// DeviceModel.swift
import Foundation
import SwiftUI   // ← вместо SwiftUICore

struct Device: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    var plant: Plant
    let colorCard: Color
    let colorNumber: Color
    let colorCardCitcle: Color
    var humidity: Int
    var temperature: Int
    var isWaterAvailable: Bool
    var isOnline: Bool

    // init из DTO
    init(dto: DeviceDTO, plants: [Plant]) {
        self.id = dto.id
        self.name = dto.id
        let p = plants.first(where: { $0.serverId == dto.plant_id })
        self.plant = p ?? Plant.placeholder(serverId: dto.plant_id)   // ← используем placeholder
        self.colorCard = .green
        self.colorNumber = .primary
        self.colorCardCitcle = .green
        self.humidity = dto.humidity ?? 0
        self.temperature = dto.temp ?? 0
        self.isWaterAvailable = (dto.water ?? 0) > 0
        self.isOnline = (dto.online ?? 0) == 1
    }

    // Явный memberwise init (чтобы точно был доступен)
    init(
        id: String,
        name: String,
        plant: Plant,
        colorCard: Color,
        colorNumber: Color,
        colorCardCitcle: Color,
        humidity: Int,
        temperature: Int,
        isWaterAvailable: Bool,
        isOnline: Bool
    ) {
        self.id = id
        self.name = name
        self.plant = plant
        self.colorCard = colorCard
        self.colorNumber = colorNumber
        self.colorCardCitcle = colorCardCitcle
        self.humidity = humidity
        self.temperature = temperature
        self.isWaterAvailable = isWaterAvailable
        self.isOnline = isOnline
    }
}

struct DevicesResponse: Codable { let devices: [DeviceDTO] }

struct DeviceDTO: Codable, Identifiable, Hashable {
    let id: String
    let fw: String?
    let last_seen_at: Int?
    let online: Int?
    let plant_id: Int?
    let humidity: Int?
    let water: Int?
    let temp: Int?
}
