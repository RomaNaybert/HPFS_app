import Combine
import Foundation

@MainActor
final class DeviceStore: ObservableObject {
    static let shared = DeviceStore()
    @Published private(set) var devices: [Device] = []

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("devices-cache.json")
    }

    func loadFromCache() {
        if let data = try? Data(contentsOf: cacheURL),
           let rows = try? JSONDecoder().decode([ServerDeviceRow].self, from: data) {
            let plants = PlantStore.shared.plants
            self.devices = rows.map { row in
                let dto = DeviceDTO(
                    id: row.device_id,
                    fw: row.firmware_version,
                    last_seen_at: row.last_seen_at,
                    online: row.online,
                    plant_id: row.plant_id,
                    humidity: row.humidity,
                    water: row.water,
                    temp: row.temp
                )
                return Device(dto: dto, plants: plants)
            }
        }
    }

    private func saveToCache(_ rows: [ServerDeviceRow]) {
        if let data = try? JSONEncoder().encode(rows) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    func reloadFromServer() async {
        do {
            let rows = try await DeviceAPI.list()
            saveToCache(rows)
            let plants = PlantStore.shared.plants
            self.devices = rows.map { row in
                let dto = DeviceDTO(
                    id: row.device_id,
                    fw: row.firmware_version,
                    last_seen_at: row.last_seen_at,
                    online: row.online,
                    plant_id: row.plant_id,
                    humidity: row.humidity,
                    water: row.water,
                    temp: row.temp
                )
                return Device(dto: dto, plants: plants)
            }
        } catch {
            print("DeviceStore.reloadFromServer error:", error)
            // оставляем кэш как есть
        }
    }

    func addClaimedDevice(id deviceId: String, plant: Plant) {
        if devices.contains(where: { $0.id == deviceId }) { return }
        let dev = Device(
            id: deviceId,
            name: deviceId,
            plant: plant,
            colorCard: .green,
            colorNumber: .primary,
            colorCardCitcle: .green,
            humidity: 0,
            temperature: 0,
            isWaterAvailable: false,
            isOnline: true
        )
        devices.append(dev)
    }
}
