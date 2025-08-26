//
//  GlassModifier.swift
//  HPFS
//
//  Created by Роман on 04.05.2025.
//

import Foundation
import SwiftUI

struct GlassRectangle: View {
    var body: some View {
        Color(hex: "#343434").opacity(0.14)
            .background(
                BlurView2(style: .systemUltraThinMaterial) // эффект стекла
            )
    }
}

struct BlurView2: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}


extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xff) / 255
        let g = Double((rgb >> 8) & 0xff) / 255
        let b = Double(rgb & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
