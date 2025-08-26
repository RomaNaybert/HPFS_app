//
//  TapBarView.swift
//  HPFS
//
//  Created by Роман on 07.05.2025.
//

import SwiftUI

enum Tab {
    case home
    case addDevice
    case threeD
    case settings
}

struct TapBarView: View {
    
    @State private var showAddPlantView = false
    @State private var showAccessPointView = false
    @State var selectedTab: Int = 1
    @State private var plusCircleSize: CGFloat = 20
    @Binding var selectedTabView: CustomTab
    @Binding var selectedItem: Int
    
    
    var position: Int {
        if selectedTab == 1 {
            return Int(CGFloat(UIScreen.main.bounds.width / 8.5))
        } else if selectedTab == 2 {
            return Int(CGFloat(UIScreen.main.bounds.width / 2.75))
        } else if selectedTab == 3 {
            return Int(CGFloat(UIScreen.main.bounds.width / 1.60))
        } else {
            return Int(CGFloat(UIScreen.main.bounds.width / 1.135))
        }
    }
    
    var circleSize: CGFloat {
        if selectedTab == 1 {
            return 100
        } else {
            return 0
        }
    }
    
    var circlePosition: CGFloat {
        if selectedTab == 1 {
            return 0
        } else {
            return 10
        }
    }
    
    var plusCirclePosition: CGFloat {
        if selectedTab == 1 {
            return -30
        } else {
            return 35
        }
    }
    
    @EnvironmentObject var plantStore: PlantStore
    @EnvironmentObject private var deviceStore: DeviceStore
    
    var body: some View {
        ZStack{
                Button(action: {
                    if selectedItem == 0 {
                        showAddPlantView.toggle()
                    } else {
                        showAccessPointView.toggle()
                    }
                }, label: {
                    ZStack{
                        Circle()
                            .fill(Color(.colorDarkGrey))
                            .frame(width: circleSize, height: 100)
                            .animation(.easeInOut, value: circleSize)
                            .padding(.top, circlePosition)
                            .animation(.easeInOut, value: circlePosition)
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: plusCircleSize, height: plusCircleSize)
                            .foregroundColor(.white)
                            .padding(.top, plusCirclePosition)
                            .animation(.easeInOut, value: plusCirclePosition)
                    }
                })
                .position(x: UIScreen.main.bounds.width/2 ,y: UIScreen.main.bounds.height/2.55)
                .fullScreenCover(isPresented: $showAddPlantView) {
                    AddPlantView()
                }
                .sheet(isPresented: $showAccessPointView) {
                    AddHPFSDeviceView()
                        .environmentObject(deviceStore)
                }
                
                HStack{
                    Rectangle()
                        .frame(width: 374, height: 51)
                        .foregroundStyle(Color(.colorDarkGrey))
                        .cornerRadius(8)
                    ZStack{
                        GlassRectangle()
                            .frame(width: 54, height: 51)
                            .cornerRadius(8)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.colorDarkGrey), lineWidth: 1.5)
                            .frame(width: 54, height: 51)
                        
                    }
                    Rectangle()
                        .frame(width: 374, height: 51)
                        .foregroundStyle(Color(.colorDarkGrey))
                        .cornerRadius(8)
                }
                .ignoresSafeArea()
                .position(x: CGFloat(position), y: UIScreen.main.bounds.height/2.35)
                .animation(.easeInOut, value: position)
                
            HStack(spacing: UIScreen.main.bounds.width/5.3){
                    Button(action: {
                        selectedTab = 1
                        plusCircleSize = 20
                        print(selectedTab)
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            selectedTabView = .home
//                        }
                    }, label: {
                        Image(selectedTab == 1 ? "plantBlack" :"plant")
                    })
                    Button(action: {
                        selectedTab = 2
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            plusCircleSize = 0
                        }
                        print(selectedTab)
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            selectedTabView = .addDevice
//                        }
                    }, label: {
                        Image(selectedTab == 2 ? "wandBlack" : "magicWand")
                    })
                    Button(action: {
                        selectedTab = 3
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            plusCircleSize = 0
                        }
                        print(selectedTab)
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            selectedTabView = .threeD
//                        }
                    }, label: {
                        Image(selectedTab == 3 ? "vectorBlack" : "vector")
                    })
                    Button(action: {
                        selectedTab = 4
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            plusCircleSize = 0
                        }
                        print(selectedTab)
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            selectedTabView = .settings
//                        }
                    }, label: {
                        Image(selectedTab == 4 ? "gearBlack" : "gear")
                    })
                }
            .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2.35)
        }
        .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2.3)
    }
}



struct TapBarViewOhnePlus: View {
    
    @State private var showAddPlantView = false
    
    @ObservedObject var plantStore: PlantStore
    
    var body: some View {
        ZStack {
            
            
            HStack{
                Rectangle()
                    .foregroundStyle(Color(.colorDarkGrey))
                    .frame(width: 24, height: 51)
                    .cornerRadius(8)
                ZStack{
                    GlassRectangle()
                        .frame(width: 54, height: 51)
                        .cornerRadius(8)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.colorDarkGrey), lineWidth: 1.5)
                        .frame(width: 54, height: 51)
                    Image("plant")
                }
                ZStack{
                    Rectangle()
                        .foregroundStyle(Color(.colorDarkGrey))
                        .frame(width: 327, height: 51)
                        .cornerRadius(8)
                    HStack(spacing: 76){
                        Image("magicWand")
                        Image("vector")
                        Image("gear")
                    }
                }
                
            }
        }
        .padding(.top, 20)
    }
}

#Preview {
    ContentView()
        .environmentObject(PlantStore())
        .environmentObject(DeviceStore())
}


//ZStack {
//    Button(action: {
//        showAddPlantView.toggle()
//    }, label: {
//        ZStack{
//            Circle()
//                .fill(Color(.colorDarkGrey))
//                .frame(width: 100, height: 100)
//            Image(systemName: "plus")
//                .resizable()
//                .frame(width: 20, height: 20)
//                .foregroundColor(.white)
//                .padding(.bottom, 30)
//        }
//    })
//    
//    .padding(.bottom, 50)
//    .fullScreenCover(isPresented: $showAddPlantView) {
//        AddPlantView(plants: $plants)
//    }
//    
//    HStack{
//        Rectangle()
//            .foregroundStyle(Color(.colorDarkGrey))
//            .frame(width: 24, height: 51)
//            .cornerRadius(8)
//        ZStack{
//            GlassRectangle()
//                .frame(width: 54, height: 51)
//                .cornerRadius(8)
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(Color(.colorDarkGrey), lineWidth: 1.5)
//                .frame(width: 54, height: 51)
//            Image("plant")
//        }
//        ZStack{
//            Rectangle()
//                .foregroundStyle(Color(.colorDarkGrey))
//                .frame(width: 327, height: 51)
//                .cornerRadius(8)
//            HStack(spacing: 76){
//                Image("magicWand")
//                Image("vector")
//                Image("gear")
//            }
//        }
//        
//    }
//}
//.padding(.top, 20)
