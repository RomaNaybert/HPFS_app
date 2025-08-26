//
//  AddPlantView.swift
//  HPFS
//
//  Created by Роман on 07.05.2025.
//

import SwiftUI

struct AddPlantView: View {
    
    @State var name: String = ""
    @State var type: String = ""
    @State var location: String = ""
    @State var humidity: Int = 0
    @State var temperature: Int = 0
    @State var imageOfPlant: Int = 0
    
    @State private var dragOffset: CGSize = .zero
    @State private var page: Int = 0
    @State private var animatioNnextScreen: Bool = false
    @State private var isDimmed = false
    @State private var isDimmed2 = false
    @Environment(\.dismiss) var dismiss
    
    var number: Int{
        plantStore.plants.count + 1
    }
    
    var plantMove: CGSize {
        if name.isEmpty || type.isEmpty {
            return CGSize(width: -150, height: 0)
        } else {
            return CGSize(width: 0, height: 0)
        }
    }
    
    var colorCard: Color {
        if number % 2 != 0 && number % 3 != 0 {
            return Color("ColorCardLightGreen")
        } else if number % 2 == 0 && number % 4 != 0 {
            return Color(.colorCardTeaGreen)
        } else if number % 3 == 0 {
            return Color(.white)
        } else {
            return Color(.colorCardPastelGreen)
        }
    }
    
    var colorCardCitcle: Color {
        if number % 2 != 0 && number % 3 != 0 {
            return Color(.colorDarkGrey)
        } else if number % 2 == 0 && number % 4 != 0 {
            return Color(.colorDarkGrey)
        } else if number % 3 == 0 {
            return Color("ColorCardPastelGreen")
        } else {
            return Color(.colorDarkGrey)
        }
    }
    
    var colorNumber: Color {
        if number % 2 != 0 && number % 3 != 0 {
            return Color(.white)
        } else if number % 2 == 0 && number % 4 != 0 {
            return Color(.white)
        } else if number % 3 == 0 {
            return Color(.colorDarkGrey)
        } else {
            return Color(.white)
        }
    }
    
    var screenMove: CGSize {
        if animatioNnextScreen {
            return CGSize(width: 0, height: 850)
        } else {
            return CGSize(width: 0, height: 0)
        }
    }
    
    @EnvironmentObject var plantStore: PlantStore
    
    var body: some View {
        NavigationStack {
            ZStack{
                
                Image("plant2_1")
                    .resizable()
                    .frame(width: 527, height: 677)
                    .offset(x: -140, y: -100)
                if UIScreen.main.bounds.width > 430{
                    Rectangle()
                        .frame(width: 1000, height: 1000)
                        .cornerRadius(UIScreen.main.bounds.width / 4)
                        .offset(x: UIScreen.main.bounds.height/(-3.5), y: 200)
                        .foregroundStyle(Color(hex: "343434"))
                } else {
                    Rectangle()
                        .frame(width: 1000, height: 1000)
                        .cornerRadius(80)
                        .offset(x: UIScreen.main.bounds.height/(-3), y: 200)
                        .foregroundStyle(Color(hex: "343434"))
                }
                
                //Первая страница
                
                if page == 0 {
                    VStack(alignment: .leading){
                        VStack(alignment: .leading, spacing: -10){
                            Text("Как зовут твоё")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                            Text("растение?")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                        }
                        Text("Введите информацию про растение")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 16))
                            .offset(y: 4)
                        Text("Название растения")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 30)
                        Text("Не более 12 символов")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 12))
                            .padding(.bottom, 3)
                        ZStack{
                            TextField("", text: $name)
                                .frame(width: 333)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(name.isEmpty ? "Введите название" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .padding(.leading, -165)
                                .allowsHitTesting(false)
                        }
                        Text("Тип растения")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 10)
                        ZStack{
                            TextField("", text: $type)
                                .frame(width: 333)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(type.isEmpty ? "Введите тип растения" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .padding(.leading, -155)
                                .allowsHitTesting(false)
                        }
                        Button(action: {
                            animatioNnextScreen = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                page = 1
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                                isDimmed = true
                            }
                        }, label: {
                            Rectangle()
                                .frame(width: 107, height: 39)
                                .foregroundStyle(name.isEmpty || type.isEmpty || name.count > 12 ? Color(.colorDarkGrey) : Color(hex: "8EB87A"))
                                .animation(.easeInOut, value: name.isEmpty || type.isEmpty || name.count > 12 ? false : true)
                                .cornerRadius(9)
                                .overlay(
                                    Text("ДАЛЬШЕ")
                                        .foregroundStyle(.white)
                                        .font(Font.custom("OpenSans-Semibold", size: 16))
                                )
                                .padding(.top, 20)
                                .offset(screenMove)
                                .animation(.easeInOut(duration: 2.8), value: screenMove)
                        })
                        .disabled(name.isEmpty || type.isEmpty || name.count > 12 ? true : false)
                    }
                    .padding(.bottom, 120)
                    .offset(screenMove)
                    .animation(.easeInOut(duration: 2.0), value: screenMove)
                    
                    
                    Button(action: {
                        print("Button tapped")
                    }, label: {
                        VStack {
                            Image("NFCcircle")
                                .padding(.top, 10)
                            VStack(spacing: -5){
                                Text("Сканировать")
                                    .foregroundStyle(Color(hex: "8EB87A"))
                                    .font(Font.custom("OpenSans-Semibold", size: 12))
                                Text("NFC")
                                    .foregroundStyle(Color(hex: "8EB87A"))
                                    .font(Font.custom("OpenSans-Semibold", size: 12))
                            }
                        }
                        .contentShape(Rectangle()) // ОГРАНИЧИВАЕМ область клика
                    })
                    .position(x: 620, y: 950)
                    .offset(screenMove)
                    .animation(.easeInOut(duration: 2.0), value: screenMove)
                    
                    Image("plant2")
                        .resizable()
                        .frame(width: 384, height: 427)
                        .padding(.top, 800)
                        .offset(plantMove)
                        .animation(.easeInOut, value: plantMove)
                        .animation(.easeInOut(duration: 2.0), value: page)
                        .offset(screenMove)
                        .animation(.easeInOut(duration: 2.0), value: screenMove)
                    
                    // Вторая страница
                    
                } else if page == 1{
                    VStack(alignment: .leading){
                        VStack(alignment: .leading, spacing: -10){
                            Text("Выбери аватар")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                            Text("растения")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                        }
                        Text("Выберите фотографию, которое напоминает ")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 16))
                            .offset(y: 4)
                        Text("Вам о Вашем растении")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 16))
                        VStack(spacing: 20){
                            HStack(spacing: 20){
                                Button(action: {
                                    imageOfPlant = 1
                                }, label: {
                                    ZStack{
                                        if imageOfPlant == 1{
                                            Rectangle()
                                                .frame(width: 155, height: 155)
                                                .foregroundColor(Color(hex: "8CB57C"))
                                                .cornerRadius(20)
                                                .shadow(color: Color(hex: "8CB57C"), radius: 20)
                                                .rotationEffect(imageOfPlant == 1 ? Angle(degrees: 5) : Angle(degrees: 0))
                                                .animation(.easeInOut, value: imageOfPlant)
                                        }
                                        Rectangle()
                                            .frame(width: 155, height: 155)
                                            .foregroundColor(Color(hex: "D9D9D9"))
                                            .cornerRadius(20)
                                            .overlay(
                                                Image("plantButton1")
                                                    .resizable()
                                                    .frame(width: 155, height: 200)
                                                    .padding(.bottom, 45)
                                            )
                                            .rotationEffect(imageOfPlant == 1 ? Angle(degrees: 5) : Angle(degrees: 0))
                                            .animation(.easeInOut, value: imageOfPlant)
                                    }
                                })
                                Button(action: {
                                    imageOfPlant = 2
                                }, label: {
                                    ZStack{
                                        if imageOfPlant == 2{
                                            Rectangle()
                                                .frame(width: 155, height: 155)
                                                .foregroundColor(Color(hex: "8CB57C"))
                                                .cornerRadius(20)
                                                .shadow(color: Color(hex: "8CB57C"), radius: 120)
                                                .rotationEffect(imageOfPlant == 2 ? Angle(degrees: 5) : Angle(degrees: 0))
                                                .animation(.easeInOut, value: imageOfPlant)
                                        }
                                        Rectangle()
                                            .frame(width: 155, height: 155)
                                            .foregroundColor(Color(hex: "D9D9D9"))
                                            .cornerRadius(20)
                                            .overlay(
                                                Image("plantButton2")
                                                    .resizable()
                                                    .cornerRadius(20)
                                                    .frame(width: 155, height: 198)
                                                    .padding(.bottom, 43)
                                            )
                                            .rotationEffect(imageOfPlant == 2 ? Angle(degrees: 5) : Angle(degrees: 0))
                                            .animation(.easeInOut, value: imageOfPlant)
                                    }
                                })
                            }
                            HStack(spacing: 15){
                                Button(action: {
                                    imageOfPlant = 3
                                }, label: {
                                    ZStack{
                                        if imageOfPlant == 3{
                                            Rectangle()
                                                .frame(width: 155, height: 155)
                                                .foregroundColor(Color(hex: "8CB57C"))
                                                .cornerRadius(20)
                                                .shadow(color: Color(hex: "8CB57C"), radius: 20)
                                                .rotationEffect(imageOfPlant == 3 ? Angle(degrees: 5) : Angle(degrees: 0))
                                                .animation(.easeInOut, value: imageOfPlant)
                                        }
                                        Rectangle()
                                            .frame(width: 155, height: 155)
                                            .foregroundColor(Color(hex: "D9D9D9"))
                                            .cornerRadius(20)
                                            .overlay(
                                                Image("plantButton3")
                                                    .resizable()
                                                    .cornerRadius(20)
                                                    .frame(width: 129, height: 152)
                                                    .padding(.bottom, -4)
                                                    .padding(.leading, -27)
                                            )
                                            .rotationEffect(imageOfPlant == 3 ? Angle(degrees: 5) : Angle(degrees: 0))
                                            .animation(.easeInOut, value: imageOfPlant)
                                    }
                                })
                                Button(action: {
                                    imageOfPlant = 4
                                }, label: {
                                    ZStack{
                                        if imageOfPlant == 4{
                                            Rectangle()
                                                .frame(width: 155, height: 155)
                                                .foregroundColor(Color(hex: "8CB57C"))
                                                .cornerRadius(20)
                                                .shadow(color: Color(hex: "8CB57C"), radius: 20)
                                                .rotationEffect(imageOfPlant == 4 ? Angle(degrees: 5) : Angle(degrees: 0))
                                                .animation(.easeInOut, value: imageOfPlant)
                                            
                                        }
                                        Rectangle()
                                            .frame(width: 155, height: 155)
                                            .foregroundColor(Color(hex: "D9D9D9"))
                                            .cornerRadius(20)
                                            .overlay(
                                                Image("plantButton4")
                                                    .resizable()
                                                    .cornerRadius(20)
                                                    .frame(width: 138, height: 172)
                                                    .padding(.bottom, 17)
                                                    .padding(.leading, 12)
                                            )
                                            .rotationEffect(imageOfPlant == 4 ? Angle(degrees: 5) : Angle(degrees: 0))
                                            .animation(.easeInOut, value: imageOfPlant)
                                        
                                    }
                                })
                            }
                            Button(action: {
                                isDimmed2 = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    page = 3
                                }
                            }, label: {
                                Rectangle()
                                    .frame(width: 147, height: 39)
                                    .foregroundStyle(imageOfPlant == 0 ? Color(.colorDarkGrey) : Color(hex: "8EB87A"))
                                    .animation(.easeInOut, value: imageOfPlant != 0 ? false : true)
                                    .cornerRadius(9)
                                    .overlay(
                                        Text("ПОДТВЕРДИТЬ")
                                            .foregroundStyle(.white)
                                            .font(Font.custom("OpenSans-Semibold", size: 16))
                                    )
                                    .padding(.top, 40)
                            })
                            .disabled(imageOfPlant == 0 ? true : false)
                        }
                        .padding(.top, 80)
                    }
                    .padding(.top, 130)
                    .opacity(!isDimmed ? 0 : 1)
                    .opacity(!isDimmed2 ? 1 : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: isDimmed)
                    .animation(.easeInOut(duration: 0.5), value: isDimmed2)
                    
                    // Третья страница
                    
                }  else if page == 3{
                    VStack(alignment: .leading){
                        VStack(alignment: .leading, spacing: -10){
                            Text("Где находится")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                            Text("твоё растение?")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                            
                        }
                        Text("Напишите комнату или место, в котором")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 16))
                            .offset(y: 4)
                        Text("расположено Ваше растение")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 16))
                        Image("selectedPlant\(imageOfPlant)")
                            .resizable()
                            .frame(width: 307, height: 308)
                        Text("В какой комнате растение?")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 10)
                        ZStack{
                            TextField("", text: $location)
                                .frame(width: 333)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(location.isEmpty ? "Введите название" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .padding(.leading, -165)
                                .allowsHitTesting(false)
                        }
                        Button(action: {
                            Task {
                                let ok = await plantStore.create(
                                    name: name,
                                    location: location,
                                    avatar: imageOfPlant,
                                    humidity: 84,
                                    temperature: 22
                                )
                                if ok { dismiss() }
                            }
                        }, label: {
                            Rectangle()
                                .frame(width: 187, height: 39)
                                .foregroundStyle((location.isEmpty || plantStore.isCreating) ? Color(.colorDarkGrey) : Color(hex: "8EB87A"))
                                .cornerRadius(9)
                                .overlay(
                                    Group {
                                        if plantStore.isCreating {
                                            ProgressView().tint(.white)     // 👈 индикатор в кнопке
                                        } else {
                                            Text("ДОБАВИТЬ РАСТЕНИЕ")
                                                .foregroundStyle(.white)
                                                .font(Font.custom("OpenSans-Semibold", size: 16))
                                        }
                                    }
                                )
                        })
                        .disabled(location.isEmpty || plantStore.isCreating)   // 👈 защита от повторных тапов
                        .animation(.easeInOut, value: plantStore.isCreating)

                    }
                    .padding(.top, 90)
                }
                
            }
            .background(Color(hex: "D9D9D9"))
            .navigationBarHidden(true)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.startLocation.y < 1000 { // свайп от края
                        dragOffset = value.translation // сдвиг пальца от начальной точки
                    }
                }
                .onEnded { value in
                    if dragOffset.height > 60 {
                        dismiss()
                        print("dismiss")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            page = 0
                            animatioNnextScreen = false
                            isDimmed = false
                            isDimmed2 = false
                        }
                    } else {
                        dragOffset = .zero
                    }
                }
        )
    }
}

#Preview {
    ContentView()
}

