//
//  PlantDetailView.swift
//  HPFS
//
//  Created by Роман on 27.04.2025.
//

import SwiftUI

struct PlantDetailView: View {
    
    @State var isFavorite: Bool = false
    @State var isWater: Bool = false
    @State var isHumidity: Bool = false
    
    @State private var dragOffset: CGSize = .zero
    @Environment(\.dismiss) var dismiss
    @Binding var plant: Plant
    @EnvironmentObject var plantStore: PlantStore
    @Binding var viewID: UUID
    @State var numberPlant: Int = 1 
    
    var splitPlantName: (String, String) {
        let characters = Array(plant.name)
        let mid = (characters.count + 1) / 2
        let firstLine = String(characters[..<mid])
        let secondLine = String(characters[mid...])
        return (firstLine, secondLine)
    }
    
    var plantNameIsBeg: Bool {
        if plant.name.count >= 8 {
            return true
        } else {
            return false
        }
    }
    
    var body: some View {
        NavigationStack{
            ScrollView(showsIndicators: false) {
                ZStack{
                    Color.clear
                        .background(
                            Image("plantBackround")
                                .resizable()
                                .scaledToFill()
                                .offset(x: 0, y: 40)
                        )
                    Color.clear
                        .background(
                            Image("backgroundPlant2")
                                .resizable()
                                .scaledToFill()
                                .offset(x: 0, y: 770)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        )
                        .zIndex(-1)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    ZStack{
                        VStack {
                            HStack {
                                ZStack {
                                    Button(action: {
                                        dismiss()
                                    }) {
                                        ZStack{
                                            Rectangle()
                                                .frame(width: 67, height: 29)
                                                .cornerRadius(5)
                                                .foregroundStyle(Color("ColorDarkGrey"))
                                            Image("arrowWhite")
                                        }
                                    }
                                }
                                Spacer()
                                Image("user_photo 1")
                                
                                
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 30)
                            
                            if plantNameIsBeg {
                                let (firstLine, secondLine) = splitPlantName
                                
                                VStack(spacing: -40) {
                                    Text(firstLine)
                                        .font(Font.custom("OpenSans-Semibold", size: 100))
                                        .foregroundStyle(Color("ColorDarkGrey"))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .padding(.horizontal, 16)
                                        .background(
                                            GlassRectangle()
                                                .cornerRadius(52)
                                                .frame(height: 30)
                                                .offset(y: 35)
                                        )
                                        .offset(x: -30)
                                    
                                    Text(secondLine)
                                        .font(Font.custom("OpenSans-Semibold", size: 100))
                                        .foregroundStyle(Color("ColorDarkGrey"))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .padding(.horizontal, 16)
                                        .background(
                                            GlassRectangle()
                                                .cornerRadius(52)
                                                .frame(height: 30)
                                                .offset(y: -12)
                                        )
                                        .offset(x: 40)
                                }
                            } else {
                                ZStack{
                                    Text(plant.name)
                                        .font(Font.custom("OpenSans-Semibold", size: 105))
                                        .foregroundStyle(Color("ColorDarkGrey"))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .background(
                                            GlassRectangle()
                                                .cornerRadius(52)
                                                .frame(height: 30)
                                                .offset(y: 35)
                                        )
                                }
                            }
                            
                            
                            Spacer()
                            
                            //Прозрачный блок "Информация"
                            
                            
                            //                        Button(action: {
                            //                            plants.removeSubrange(plants.firstIndex(of: plant)!..<plants.firstIndex(of: plant)!+1)
                            //                        }, label: {
                            //                            ZStack{
                            //                                Rectangle()
                            //                                    .foregroundStyle(Color("ColorDarkGrey"))
                            //                                    .frame(width: 240, height: 38)
                            //                                    .cornerRadius(10)
                            //                                Text("Delete")
                            //                                    .foregroundStyle(.white)
                            //                                    .font(Font.custom("OpenSans-Semibold", size: 26))
                            //                                    .padding(.leading, 55)
                            //                                Image(systemName: "trash")
                            //                                    .resizable()
                            //                                    .frame(width: 73, height: 18)
                            //                                    .foregroundStyle(.white)
                            //                                    .padding(.leading, -90)
                            //                            }
                            //                        })
                            
                        }
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: UIScreen.main.bounds.width - 35, height: UIScreen.main.bounds.height - 180)
                            .padding(.bottom, 65)
                        
                        // Первая прозрачная плашка (Полить, увлажнить, сердце)
                        
                        ZStack{
                            GlassRectangle()
                                .frame(width: 390, height: 112)
                                .cornerRadius(30)
                                .offset(x: -45, y: 40)
                            
                            Rectangle() // дырка
                                .cornerRadius(10)
                                .blendMode(.destinationOut)
                                .frame(width: 74, height: 80)
                                .offset(x: 80, y: 40)
                        }
                        .compositingGroup()
                        .allowsHitTesting(false)
                        
                        Button(action: {
                            isFavorite.toggle()
                        }, label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .resizable()
                                .frame(width: 46, height: 40)
                                .foregroundStyle(.white)
                        })
                        .padding(.top, 80)
                        .padding(.leading, 160)
                        
                        Button(action: {
                            isWater.toggle()
                        }, label: {
                            ZStack{
                                Rectangle()
                                    .foregroundStyle(Color("ColorDarkGrey"))
                                    .frame(width: 240, height: 38)
                                    .cornerRadius(10)
                                Text("Полить")
                                    .foregroundStyle(.white)
                                    .font(Font.custom("OpenSans-Semibold", size: 26))
                                    .kerning(-1.5)
                                Image(systemName: isWater ? "drop.fill" : "drop")
                                    .resizable()
                                    .frame(width: 15, height: 20)
                                    .foregroundStyle(.white)
                                    .padding(.leading, -90)
                            }
                        })
                        .padding(.top, 30)
                        .padding(.leading, -200)
                        
                        Button(action: {
                            isHumidity.toggle()
                        }, label: {
                            ZStack{
                                Rectangle()
                                    .foregroundStyle(Color("ColorDarkGrey"))
                                    .frame(width: 240, height: 38)
                                    .cornerRadius(10)
                                Text("Увлажнить")
                                    .foregroundStyle(.white)
                                    .font(Font.custom("OpenSans-Semibold", size: 26))
                                    .padding(.leading, 55)
                                    .kerning(-1.5)
                                Image(systemName: isHumidity ? "humidity.fill" : "humidity")
                                    .resizable()
                                    .frame(width: 23, height: 18)
                                    .foregroundStyle(.white)
                                    .padding(.leading, -90)
                            }
                        })
                        .padding(.top, 130)
                        .padding(.leading, -200)
                        
                        // вторая прозрачная плашка (показания датчиков)
                        
                        ZStack{
                            GlassRectangle()
                                .frame(width: 352, height: 148)
                                .cornerRadius(22)
                                .offset(x: 130, y: 190)
                            Text("Показания")
                                .foregroundStyle(Color(.white))
                                .font(Font.custom("OpenSans-Semibold", size: 26))
                                .offset(x: 45, y: 145)
                                .kerning(-1.5)
                            Text("датчиков")
                                .foregroundStyle(Color(.white))
                                .font(Font.custom("OpenSans-Semibold", size: 26))
                                .offset(x:35, y: 170)
                                .kerning(-1.5)
                            Image(systemName: "humidity.fill")
                                .resizable()
                                .frame(width: 24, height: 19)
                                .foregroundStyle(.white)
                                .offset(x: -10, y: 210)
                            Image(systemName: "thermometer.variable")
                                .resizable()
                                .frame(width: 11, height: 22)
                                .foregroundStyle(.white)
                                .offset(x: 100, y: 210)
                            Text("\(plant.temperature)°C")
                                .foregroundStyle(Color(.white))
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                                .offset(x: 150, y: 225)
                                .kerning(-1.5)
                            Text("\(plant.humidity)%")
                                .foregroundStyle(Color(.white))
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                                .offset(x: 40, y: 225)
                                .kerning(-1.5)
                            
                        }
                        
                        //Стрелка вниз в круге
                        
                        Circle()
                            .frame(width: 38, height: 38)
                            .foregroundStyle(.white)
                            .overlay(
                                Image(systemName: "arrow.down")
                            )
                            .offset(y: 325)
                        
                        
                        ZStack{
                            GlassRectangle()
                                .frame(width: UIScreen.main.bounds.width-40, height: 73)
                                .cornerRadius(22)
                                .offset(y: 40)
                            Text("Информация")
                                .font(Font.custom("OpenSans-Semibold", size: 29))
                                .offset(y: 40)
                                .kerning(-1.5)
                            Text("Информация")
                                .font(Font.custom("OpenSans-Semibold", size: 29))
                                .offset(x: -200, y: 40)
                                .kerning(-1.5)
                            Text("Информация")
                                .font(Font.custom("OpenSans-SemiBold", size: 29))
                                .offset(x: 200, y: 40)
                                .kerning(-1.5)
                        }
                        .offset(y: 385)
                        
                        
                    }
                }
                ZStack{
                    VStack{
                        ZStack{
                            GlassRectangle()
                                .frame(width: 350, height: 245)
                                .cornerRadius(22)
                            VStack(alignment: .leading, spacing: -10){
                                Text("Рекомендуемые")
                                    .foregroundStyle(Color(hex: "272727"))
                                    .font(Font.custom("OpenSans-Semibold", size: 25))
                                    .kerning(-1.5)
                                Text("условия")
                                    .foregroundStyle(Color(hex: "272727"))
                                    .font(Font.custom("OpenSans-Semibold", size: 25))
                                    .kerning(-1.5)
                            }
                            .offset(x: -40, y: -70)
                            Image(systemName: "humidity.fill")
                                .resizable()
                                .frame(width: 24, height: 19)
                                .offset(x: -125, y: -10)
                                .lineSpacing(-70)
                            Text("\(plant.temperature)°C")
                                .foregroundStyle(Color(hex: "272727"))
                                .font(Font.custom("OpenSans-Semibold", size: 47))
                                .offset(x: -53, y: 70)
                            Image(systemName: "thermometer.variable")
                                .resizable()
                                .frame(width: 12, height: 18)
                                .offset(x: -125, y: 60)
                                .lineSpacing(-70)
                            Text("\(plant.humidity)%")
                                .foregroundStyle(Color(hex: "272727"))
                                .font(Font.custom("OpenSans-Semibold", size: 47))
                                .offset(x: -53, y: 0)
                                .lineSpacing(-70)
                            Text("температура")
                                .foregroundStyle(Color(hex: "272727"))
                                .font(Font.custom("OpenSans-Semibold", size: 25))
                                .offset(x: 85, y: 52)
                                .kerning(-1.5)
                            Text("влажность")
                                .foregroundStyle(Color(hex: "272727"))
                                .font(Font.custom("OpenSans-Semibold", size: 25))
                                .offset(x: 72, y: -15)
                                .kerning(-1.5)
                        }
                        .padding(.top, 75)
                        
                        
                        Button(action: {}, label: {
                            ZStack{
                                Rectangle()
                                    .frame(width: 349, height: 37)
                                    .foregroundStyle(Color(hex: "272727"))
                                    .cornerRadius(8)
                                HStack{
                                    Spacer()
                                    Spacer()
                                    Image("liveWaves")
                                        .resizable()
                                        .frame(width: 23, height: 15)
                                    Spacer()
                                    Text("Прямая трансляция")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 22))
                                        .kerning(-1.5)
                                    Spacer()
                                    Image("liveWaves")
                                        .resizable()
                                        .frame(width: 23, height: 15)
                                    Spacer()
                                    Spacer()
                                }
                            }
                            .padding(.top, -15)
                        })
                        
                        ZStack{
                            GlassRectangle()
                                .frame(width: 350, height: 245)
                                .cornerRadius(22)
                            VStack(alignment: .leading, spacing: 10){
                                Text("Уведомления")
                                    .foregroundStyle(Color(hex: "FFFFFF"))
                                    .font(Font.custom("OpenSans-Semibold", size: 25))
                                    .kerning(-1.5)
                                ZStack{
                                    Rectangle()
                                        .frame(width: 279, height: 37)
                                        .foregroundStyle(Color(hex: "272727"))
                                        .cornerRadius(8)
                                    Text("Вкл")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 22))
                                        .kerning(-1.5)
                                }
                                VStack(alignment: .leading, spacing: -10){
                                    Text("Напоминать о пливе")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 25))
                                        .kerning(-1.5)
                                    Text("каждые")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 25))
                                        .kerning(-1.5)
                                }
                                ZStack{
                                    Rectangle()
                                        .frame(width: 279, height: 37)
                                        .foregroundStyle(Color(hex: "272727"))
                                        .cornerRadius(8)
                                    Text("3 дня")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 22))
                                        .kerning(-1.5)
                                }
                            }
                        }
                        Button(action: {}, label: {
                            ZStack{
                                Rectangle()
                                    .frame(width: 349, height: 37)
                                    .foregroundStyle(Color(hex: "272727"))
                                    .cornerRadius(8)
                                HStack{
                                    Spacer()
                                    Spacer()
                                    Image("remoteDevice")
                                        .resizable()
                                        .frame(width: 17, height: 18)
                                    Spacer()
                                    Text("Устройство есть")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 22))
                                        .kerning(-1.5)
                                    Spacer()
                                    Image("remoteDevice")
                                        .resizable()
                                        .frame(width: 17, height: 18)
                                    Spacer()
                                    Spacer()
                                }
                            }
                        })
                        Button(action: {
                            Task {
                                await plantStore.delete(serverId: plant.serverId)
                                dismiss()
                            }
                        }, label: {
                            ZStack{
                                Rectangle()
                                    .frame(width: 349, height: 37)
                                    .foregroundStyle(Color(hex: "EC8B8B"))
                                    .cornerRadius(8)
                                HStack{
                                    Image(systemName: "trash")
                                        .resizable()
                                        .frame(width: 17, height: 18)
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                    Text("  Удалить растение")
                                        .foregroundStyle(Color(hex: "FFFFFF"))
                                        .font(Font.custom("OpenSans-Semibold", size: 22))
                                        .kerning(-1.5)
                                }
                            }
                        })

//                        TapBarView(selectedTabView: .constant(.home))
//                            .padding(.top, 20)
                    }
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
            .background(Color(red: 239/255, green: 239/255, blue: 239/255))
            
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.startLocation.x < 30 { // свайп от края
                        dragOffset = value.translation // сдвиг пальца от начальной точки
                    }
                }
                .onEnded { value in
                    if dragOffset.width > 60 {
                        dismiss()
                    } else {
                        dragOffset = .zero
                    }
                }
        )
    }
}


#Preview {
    PlantDetailView(
        plant: .constant(
            Plant(
                serverId: 1,
                name: "Спатифиллум",
                location: "Дом",
                colorCard: Color("ColorCardLightGreen"),
                colorNumber: Color(.white),
                colorCardCitcle: Color(.colorDarkGrey),
                humidity: 84,
                temperature: 22)
        ),
        viewID: .constant(UUID())
    )
    .environmentObject(PlantStore())
}
