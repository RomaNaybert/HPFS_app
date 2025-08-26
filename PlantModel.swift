//
//  PlantModel.swift
//  HPFS
//
//  Created by Роман on 23.04.2025.
//

import Foundation
import SwiftUICore

struct Plant: Identifiable, Equatable, Hashable {
    let id = UUID()
    let serverId: Int
    let name: String
    let location: String
    let colorCard: Color
    let colorNumber: Color
    let colorCardCitcle: Color
    let humidity: Int
    let temperature: Int
}

extension Plant {
    static func placeholder(serverId: Int?) -> Plant {
        Plant(
            serverId: serverId ?? -1,
            name: "Растение",
            location: "",
            colorCard: .gray.opacity(0.2),
            colorNumber: .secondary,
            colorCardCitcle: .gray.opacity(0.2),
            humidity: 0,
            temperature: 0
        )
    }
}
