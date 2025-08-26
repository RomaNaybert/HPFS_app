//
//  AutoNewDeviceView.swift
//  HPFS
//
//  Created by Роман on 18.08.2025.
//

import SwiftUI

struct AutoNewDeviceView: View {
    // Настраиваемые параметры
    var deviceTitle: String = "Найдены поблизости"
    var deviceName: String = "HPFS AutoWatering"
    var imageName: String = "3D-device-autowatering2"
    var onClose: (() -> Void)? = nil
    var onConnect: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var appear = false
    @State private var isConnecting = false

    var body: some View {
        ZStack {
            // Фон затемнения при показе как модалки поверх основного экрана
            Color.black.opacity(appear ? 0.25 : 0.0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.25), value: appear)

            // Карточка
            VStack(spacing: 0) {
                header
                content
                cta
            }
            .overlay(closeButton, alignment: .topTrailing)
            .accessibilityElement(children: .contain)
            .modifier(GlassCard(cornerRadius: 28))
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.15), radius: 22, x: 0, y: 10)
            .frame(maxWidth: 560)
            .transition(
                .asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                )
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: appear)
            .padding(.horizontal, 16)
            
        }
        .onAppear {
            withAnimation { appear = true }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Text(deviceTitle)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color(hex: "272727"))
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .padding(.horizontal, 18)

            Text(deviceName)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
                .accessibilityLabel("Устройство: \(deviceName)")
        }
    }

    private var content: some View {
        GeometryReader { proxy in
            // Адаптивный размер картинки
            let side = min(proxy.size.width * 0.7, 280)
            VStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 300)
        .padding(.top, 4)
        .padding(.horizontal, 12)
    }

    private var cta: some View {
        VStack(spacing: 14) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                connect()
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .imageScale(.medium)
                    }
                    Text(isConnecting ? "Подключаем…" : "Подключить")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PrimaryCapsuleButton(color: Color(hex: "51945E")))
            .disabled(isConnecting)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var closeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .contentShape(Circle())
                .padding(10)
        }
        .accessibilityLabel("Закрыть")
        .accessibilityAddTraits(.isButton)
        .hitSlopInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
    }

    // MARK: - Actions

    private func connect() {
        guard !isConnecting else { return }
        isConnecting = true

        // Эмуляция быстрых шагов (подключение/успех).
        // Здесь вставь свою реальную логику сканирования и подключения.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            isConnecting = false
            onConnect?()
            close()
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.2)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onClose?()
            // Если показано как sheet — закроется
            dismiss()
        }
    }
}

// MARK: - Styles & Helpers

struct PrimaryCapsuleButton: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .background(color.opacity(configuration.isPressed ? 0.85 : 1.0), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.35), radius: 10, x: 0, y: 6)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            )
    }
}

// Увеличиваем область нажатия для маленьких элементов
fileprivate extension View {
    func hitSlopInsets(_ insets: EdgeInsets) -> some View {
        contentShape(Rectangle())
            .padding(EdgeInsets(top: -insets.top, leading: -insets.leading, bottom: -insets.bottom, trailing: -insets.trailing))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(colors: [.green.opacity(0.45), .purple.opacity(0.45)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        AutoNewDeviceView(
            deviceTitle: "Нашли поблизости:",
            deviceName: "HPFS AutoWatering #0238",
            onClose: { print("closed") },
            onConnect: { print("connected") }
        )
    }
}
