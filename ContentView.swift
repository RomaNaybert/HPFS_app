//
//  ContentView.swift
//  HPFS
//
//  Created by Роман on 20.04.2025.
//

import SwiftUI
import UIKit

enum CustomTab {
    case home
    case addDevice
    case threeD
    case settings
}

struct GlassSegmentedControl: UIViewRepresentable {
    @Binding var selection: Int
    let items: [String]
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        // Эффект размытия стекла
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 10
        blurView.layer.borderWidth = 1
        blurView.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        blurView.clipsToBounds = true
        
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = selection
        control.selectedSegmentTintColor = UIColor(red: 39/255, green: 39/255, blue: 39/255, alpha: 1)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
        control.backgroundColor = .clear
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        blurView.contentView.addSubview(control)
        
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 4),
            control.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -4),
            control.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 4),
            control.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -4),
        ])
        
        return blurView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        if let control = uiView.contentView.subviews.first as? UISegmentedControl {
            control.selectedSegmentIndex = selection
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }
    
    class Coordinator: NSObject {
        var selection: Binding<Int>
        init(selection: Binding<Int>) { self.selection = selection }
        
        @objc func valueChanged(_ sender: UISegmentedControl) {
            selection.wrappedValue = sender.selectedSegmentIndex
        }
    }
}
struct ContentView: View {
    
    init() {
        //        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color(red: 30, green: 30, blue: 30))
        
        //MARK: изменить цвет
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color(red: 39/255, green: 39/255, blue: 39/255))
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
        UISegmentedControl.appearance().frame.size.height = 37.0
        UISegmentedControl.appearance().tintColor = UIColor(Color(red: 39/255, green: 39/255, blue: 39/255))
        UISegmentedControl.appearance().backgroundColor = UIColor(Color(white: 255/255, opacity: 0.5))
        UISegmentedControl.appearance().backgroundColor = UIColor.white.withAlphaComponent(0.5)
    }
    
    @State private var expandedPlantID: UUID?
    @State private var expandedDeviceID: String?
    @State var selectedItem = 0
    @State var selectedTabView: CustomTab = .home
    @State private var viewID = UUID()
    @State private var listOpacity: Double = 0
    @EnvironmentObject var plantStore: PlantStore
    @EnvironmentObject var deviceStore: DeviceStore
    @EnvironmentObject var session: Session
    @State private var isKeyboardVisible = false
    @State private var dragOffset: CGSize = .zero
    @State private var showLogoutConfirm = false
//    @StateObject private var wifi = WiFiSSIDMonitor()
//    @State var showAuto = false
//    @StateObject private var presence = SetupPresenceMonitor()  // новый BLE монитор
        
    var body: some View {
        NavigationStack {
            ZStack{
                VStack(spacing: 0) {
                    Group {
                        switch selectedTabView {
                        case .home:
                                ZStack{
                                    Image("PlantPNG2")
                                        .resizable()
                                        .frame(width: 377, height: 290)
                                        .position(x: UIScreen.main.bounds.width/2.3, y: UIScreen.main.bounds.height/1.34)
                                        .zIndex(1) // Поверх слоя
                                        .allowsHitTesting(false) // Пропускает нажатия сквозь себя
                                        .ignoresSafeArea(.keyboard)
                                    //                    .onAppear{
                                    //                        for family in UIFont.familyNames {
                                    //                            print(">> \(family)")
                                    //                            for name in UIFont.fontNames(forFamilyName: family) {
                                    //                                print("   \(name)")
                                    //                            }
                                    //                        }
                                    //                    }
                                    ZStack{
                                        VStack{
                                            Image("PlantPNG1")
                                                .resizable()
                                                .frame(width: 450, height: 377)
                                                .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/11)
                                                .ignoresSafeArea(.keyboard)
                                        }
                                        VStack {
                                            HStack{
                                                VStack(alignment: .leading, spacing: -10){
                                                    Text("Мои")
                                                        .font(Font.custom("OpenSans-Semibold", size: 33))
                                                        .kerning(-1.5)
                                                    Text(selectedItem == 0 ? "растения" : "устройства")
                                                        .font(Font.custom("OpenSans-Semibold", size: 33))
                                                        .kerning(-1.5)
                                                }
                                                
                                                Spacer()
                                                Button { showLogoutConfirm = true } label: {
                                                    Image("user_photo 1")
                                                }
                                                .confirmationDialog("Выйти из аккаунта?", isPresented: $showLogoutConfirm) {
                                                    Button("Выйти", role: .destructive) { session.signOut() }
                                                    Button("Отмена", role: .cancel) {}
                                                }

                                            }
                                            .padding(.horizontal, 30)
                                            GlassSegmentedControl(selection: $selectedItem, items: ["Растения", "Устройства"])
                                                .frame(width: UIScreen.main.bounds.width/1.15, height: 40)
                                            
                                            SearchFieldView(selectedItem: $selectedItem)
                                                .padding(.vertical, 5)
                                                .ignoresSafeArea(.all)
                                                .animation(.easeInOut, value: isKeyboardVisible)
                                            
                                            
                                            if selectedItem == 0 {
                                                if !plantStore.plants.isEmpty {
                                                    PlantCardsList(
                                                        plants: plantStore.plants,
                                                        expandedID: $expandedPlantID,
                                                        plantStore: plantStore,
                                                        viewID: $viewID,
                                                        listOpacity: listOpacity
                                                    )
                                                } else {
                                                    // твой пустой стейт растений как был
                                                    Spacer()
                                                    VStack(alignment: .center, spacing: 4){
                                                        VStack(alignment: .center, spacing: -5){
                                                            Text("Эта страница мечтает")
                                                                .foregroundStyle(Color(hex: "272727"))
                                                                .font(Font.custom("OpenSans-Sемibold", size: 25))
                                                            Text("о листьях. Поможем?")
                                                                .foregroundStyle(Color(hex: "272727"))
                                                                .font(Font.custom("OpenSans-Sемibold", size: 25))
                                                        }
                                                        Text("Добавьте свое первое растение!")
                                                            .foregroundStyle(Color(hex: "272727"))
                                                            .font(Font.custom("OpenSans", size: 16))
                                                        Image(systemName: "arrow.down")
                                                            .resizable()
                                                            .frame(width: UIScreen.main.bounds.width * 0.1, height: UIScreen.main.bounds.height * 0.06)
                                                            .padding(.top, 180)
                                                        Spacer()
                                                    }
                                                    .padding(.top, 60)
                                                    Spacer()
                                                }
                                            } else {
                                                if !deviceStore.devices.isEmpty {
                                                    DeviceCardsList(
                                                        devices: deviceStore.devices,
                                                        expandedID: $expandedDeviceID,
                                                        deviceStore: deviceStore,
                                                        viewID: $viewID,
                                                        listOpacity: listOpacity
                                                    )
                                                } else {
                                                    // твой пустой стейт устройств как был
                                                    Spacer()
                                                    VStack(alignment: .center, spacing: 4){
                                                        VStack(alignment: .center, spacing: -5){
                                                            Text("Пока вся работа на вас.")
                                                                .foregroundStyle(Color(hex: "272727"))
                                                                .font(Font.custom("OpenSans-Семibold", size: 25))
                                                            Text("Давайте это исправим!")
                                                                .foregroundStyle(Color(hex: "272727"))
                                                                .font(Font.custom("OpenSans-Семibold", size: 25))
                                                        }
                                                        Text("Добавьте свое первое устройство!")
                                                            .foregroundStyle(Color(hex: "272727"))
                                                            .font(Font.custom("OpenSans", size: 16))
                                                        Image(systemName: "arrow.down")
                                                            .resizable()
                                                            .frame(width: UIScreen.main.bounds.width * 0.1, height: UIScreen.main.bounds.height * 0.06)
                                                            .padding(.top, 180)
                                                        Spacer()
                                                    }
                                                    .padding(.top, 60)
                                                    Spacer()
                                                }
                                            }
                                            
                                            
                                        }
                                        .animation(.bouncy, value: selectedItem)
                                    }
                                }
                                .animation(.easeInOut, value: expandedPlantID)
                                .padding(.top, 40)
                                .background(Color(red: 239/255, green: 239/255, blue: 239/255))
                                .ignoresSafeArea(.keyboard)
                                .navigationDestination(for: Plant.self) { plant in
                                    if let index = plantStore.plants.firstIndex(where: { $0.id == plant.id }) {
                                        PlantDetailView(plant: $plantStore.plants[index], viewID: $viewID)
                                    } else {
                                        Text("Ошибка: растение не найдено")
                                    }
                                }
                                .onChange(of: plantStore.plants.count) { _ in
                                   
                                        listOpacity = 0
                                    viewID = UUID()
                                    
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 1.0)) {
                                            listOpacity = 1.0
                                        }
                                    }

                                }
                                .onAppear {
                                            withAnimation(.easeInOut(duration: 1.5)) {
                                                listOpacity = 1
                                            }
                                        }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if value.startLocation.x < 1000 { // свайп от края
                                                dragOffset = value.translation // сдвиг пальца от начальной точки
                                            }
                                        }
                                        .onEnded { value in
                                            if dragOffset.width < 60 {
                                                selectedItem = 1
                                            } else if dragOffset.width > 60{
                                                selectedItem = 0
                                            } else {
                                                dragOffset = .zero
                                            }
                                        }
                                )
                            
                            
                            
                            .navigationBarHidden(false)
                            .ignoresSafeArea(.keyboard)
                        case .threeD:
//                            ThreeD(selectedTabView: $selectedTabView)
                            AccessPointListView()
                        case .settings:
                            SettingsView(selectedTabView: $selectedTabView)
                        case .addDevice:
                            ProfileView(selectedTabView: $selectedTabView)
                        }
                    }
                }
                .animation(.easeInOut, value: selectedTabView)
                
//                if showAuto == true {
//                    AutoNewDeviceView()
//                        .animation(.easeInOut, value: showAuto)
//                        .environmentObject(deviceStore)
//                        .environmentObject(plantStore)
//                }

                TapBarView(selectedTabView: $selectedTabView, selectedItem: $selectedItem)
                    .zIndex(1)
                    .offset(y: 380)
            }
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
        }
        .onChange(of: selectedItem) { new in
            if new == 1 {
                Task { await deviceStore.reloadFromServer() }
            }
        }
//        .onAppear {
//            vm.onDeviceClaimed = { deviceID, plant in
//                deviceStore.addClaimedDevice(id: deviceID, plant: plant) // локальный кэш + UI
//                // (опционально) перетянуть актуальный список с сервера:
//                Task { await deviceStore.syncFromServer() }
//            }
//        }
//        .onChange(of: wifi.isInSetupAP) { inSetup in
//            showAuto = inSetup
//        }
        .onAppear {
            plantStore.loadFromCache()               // мгновенно показываем кэш
            Task { await plantStore.fetchAll() }     // затем обновляем с сервера
            deviceStore.loadFromCache()
            Task { await deviceStore.reloadFromServer() }
        }
        .onChange(of: selectedItem) { val in
            if val == 1 {
                Task { await deviceStore.reloadFromServer() }
            }
        }
        .ignoresSafeArea(.keyboard)
        .id(viewID)
        .environmentObject(plantStore)
        .environmentObject(deviceStore)
        .onAppear {
                    // Подписка на уведомления
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                        isKeyboardVisible = true
                    }
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                        isKeyboardVisible = false
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self)
                }
    }
}



#Preview {
    ContentView()
        .environmentObject(PlantStore())
        .environmentObject(DeviceStore())
}

//            ScrollView {
//                VStack() {
//                    ForEach(plants) { plant in
//                        PlantCardView(
//                            plant: plant,
//                            isExpanded: expandedPlantID == plant.id,
//                            onTap: {
//                                if expandedPlantID == plant.id {
//                                    expandedPlantID = nil
//                                } else {
//                                    expandedPlantID = plant.id
//                                }
//                            }
//                        )
//                    }
//                }
//            }


struct ProfileView: View {
    @Binding var selectedTabView: CustomTab
    var body: some View {
        Text("👤 Profile").font(.largeTitle)
    }
}

struct ThreeD: View {
    @Binding var selectedTabView: CustomTab
    var body: some View {
        Text("🖼️ 3D").font(.largeTitle)
    }
}


// MARK: - PlantCardsList
private struct PlantCardsList: View {
    let plants: [Plant]
    @Binding var expandedID: UUID?
    @ObservedObject var plantStore: PlantStore
    @Binding var viewID: UUID
    var listOpacity: Double

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: -50) {
                ForEach(plants.indices, id: \.self) { idx in
                    let plant = plants[idx]
                    GeometryReader { geo in
                        let globalMinY = geo.frame(in: .global).minY
                        let stickOffset = min(0, globalMinY - 310)
                        let fadeStart = UIScreen.main.bounds.height / 3.9
                        let raw = Double(globalMinY - fadeStart) / 70.0
                        let opacity = min(1.0, max(0.2, raw))

                        PlantCardView(
                            plant: plant,
                            isExpanded: expandedID == plant.id,
                            onTap: {
                                expandedID = (expandedID == plant.id) ? nil : plant.id
                            },
                            plantStore: plantStore,
                            viewID: $viewID,
                            numberPlant: idx + 1
                        )
                        .ignoresSafeArea(.keyboard)
                        .offset(y: -stickOffset)
                        .opacity(opacity)
                        .contentShape(Rectangle())
                        .allowsHitTesting(opacity > 0.3)
                        .zIndex(Double(plants.count + idx))
                    }
                    .frame(height: expandedID == plant.id ? 310 : 160)
                }
            }
            .padding(.horizontal, 10)
        }
        .ignoresSafeArea(.keyboard)
        .opacity(listOpacity)
    }
}

// MARK: - DeviceCardsList
private struct DeviceCardsList: View {
    let devices: [Device]
    @Binding var expandedID: String?
    @ObservedObject var deviceStore: DeviceStore
    @Binding var viewID: UUID
    var listOpacity: Double

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: -50) {
                ForEach(devices.indices, id: \.self) { idx in
                    let device = devices[idx]
                    GeometryReader { geo in
                        let globalMinY = geo.frame(in: .global).minY
                        let stickOffset = min(0, globalMinY - 310)
                        let fadeStart = UIScreen.main.bounds.height / 3.9
                        let raw = Double(globalMinY - fadeStart) / 70.0
                        let opacity = min(1.0, max(0.2, raw))

                        DeviceCardView(
                            device: device,
                            isExpanded: expandedID == device.id,
                            onTap: {
                                // ВАЖНО: используем expandedDeviceID, а не expandedPlantID
                                expandedID = (expandedID == device.id) ? nil : device.id
                            },
                            deviceStore: deviceStore,
                            viewID: $viewID,
                            numberDevice: idx + 1
                        )
                        .ignoresSafeArea(.keyboard)
                        .offset(y: -stickOffset)
                        .opacity(opacity)
                        .contentShape(Rectangle())
                        .allowsHitTesting(opacity > 0.3)
                        .zIndex(Double(devices.count + idx))
                    }
                    .frame(height: expandedID == device.id ? 310 : 160)
                }
            }
            .padding(.horizontal, 10)
        }
        .ignoresSafeArea(.keyboard)
        .opacity(listOpacity)
    }
}
