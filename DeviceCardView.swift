//
//  DeviceCardView.swift
//  HPFS
//
//  Created by Роман on 07.08.2025.
//

import SwiftUI

struct DeviceCardView: View {
    @State var device: Device
    let isExpanded: Bool
    let onTap: () -> Void
    @ObservedObject var deviceStore: DeviceStore
    @Binding var viewID: UUID
    
    @State var isSilent: Bool = false
    @State var numberDevice: Int = 1
    
    
    var body: some View {
        VStack{
            HStack {
                ZStack{
                    Circle()
                        .frame(width: 52, height: 52)
                        .foregroundStyle(device.colorCardCitcle)
                    Text("\(numberDevice)")
                        .padding(.bottom, 30)
                        .foregroundStyle(device.colorNumber)
                        .bold()
                        .font(Font.custom("OpenSans-Semibold", size: 50))
                }
                .padding(.leading, 15)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(device.name)
                        .font(Font.custom("OpenSans-Semibold", size: 26))
                    Text(device.isOnline ? "В сети" : "Не в сети")
                        .font(Font.custom("OpenSans-Semibold", size: 18))
                        .foregroundStyle(Color(red: 39/255, green: 39/255, blue: 39/255))
                        .opacity(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            
            if isExpanded {
                HStack() {
                    Image(systemName: "humidity.fill")
                        .resizable()
                        .frame(width: 24, height: 18)
                        .foregroundStyle(device.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .offset(y: -20)
                        .padding(.leading, 20)
                    Text("\(device.humidity)%")
                        .foregroundStyle(device.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .bold()
                        .font(Font.custom("OpenSans-Semibold", size: 35))
                    Spacer()
                    Image(systemName: "thermometer.variable")
                        .resizable()
                        .frame(width: 9, height: 18)
                        .foregroundStyle(device.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .offset(y: -20)
                        .padding(.leading, 20)
                    Text(device.isWaterAvailable ? "Есть" : "Нет" )
                        .foregroundStyle(device.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .bold()
                        .font(Font.custom("OpenSans-Semibold", size: 35))
                    Spacer()
                    Spacer()
                    Spacer()
                    Button(action: {
                        isSilent.toggle()
                    }, label: {
                        Image(systemName: "\(isSilent ? "bell.slash" : "bell")")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundStyle(device.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                            .bold()
                    })
                    .animation(.snappy, value: isSilent)
                }
                .font(.subheadline)
                
                NavigationLink { DeviceDetailView(device: device)
                } label: {
                    HStack {
                        Text("Подробнее")
                            .font(Font.custom("OpenSans-Semibold", size: 18))
                            .foregroundStyle(Color(red: 39/255, green: 39/255, blue: 39/255))
                            .opacity(0.6)
                        Spacer()
                        Image("arrowSVG")
                            .resizable()
                            .frame(width: 52, height: 32)
                            .padding(.leading, 20)
                    }
                    .padding(8)
                    .background(device.colorCard == Color(.white) ? Color("ColorCardPastelGreen") : Color(red: 239/255, green: 239/255, blue: 239/255))
                    .cornerRadius(10)
                }
            }
            Spacer()
        }
        .frame(height: isExpanded ? 280 : 130)
        .padding()
        .background(device.colorCard)
        .cornerRadius(28)
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut, value: isExpanded)
        .padding(.horizontal)
    }
}


#Preview {
    @State var sampleDevice = Device(id: "-1", name: "HPFS", plant: Plant(serverId: 1, name: "1Замиокулькас", location: "в кабинете", colorCard: Color("ColorCardPastelGreen"), colorNumber: Color.white, colorCardCitcle: Color(red: 39/255, green: 39/255, blue: 39/255), humidity: 84, temperature: 22), colorCard: Color("ColorCardPastelGreen"), colorNumber: Color.white, colorCardCitcle: Color(red: 39/255, green: 39/255, blue: 39/255), humidity: 84, temperature: 22, isWaterAvailable: true, isOnline: true)
    @State var sampleDevices = [sampleDevice]

    DeviceCardView(
        device: sampleDevice,
        isExpanded: true,
        onTap: {}, deviceStore: DeviceStore(),
        viewID: .constant(UUID()), numberDevice: 1
    )
    DeviceCardView(
        device: sampleDevice,
        isExpanded: false,
        onTap: {}, deviceStore: DeviceStore(),
        viewID: .constant(UUID()), numberDevice: 1
    )
}
