//
//  Untitled.swift
//  HPFS
//
//  Created by Роман on 23.04.2025.
//

import SwiftUI

struct PlantCardView: View {
    @State var plant: Plant
    let isExpanded: Bool
    let onTap: () -> Void
    @ObservedObject var plantStore: PlantStore
    @Binding var viewID: UUID
    
    @State var isSilent: Bool = false
    @State var numberPlant: Int = 1
    
    
    var body: some View {
        VStack{
            HStack {
                ZStack{
                    Circle()
                        .frame(width: 52, height: 52)
                        .foregroundStyle(plant.colorCardCitcle)
                    Text("\(numberPlant)")
                        .padding(.bottom, 30)
                        .foregroundStyle(plant.colorNumber)
                        .bold()
                        .font(Font.custom("OpenSans-Semibold", size: 50))
                }
                .padding(.leading, 15)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(plant.name)
                        .font(Font.custom("OpenSans-Semibold", size: 26))
                    Text(plant.location)
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
                        .foregroundStyle(plant.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .offset(y: -20)
                        .padding(.leading, 20)
                    Text("\(plant.humidity)%")
                        .foregroundStyle(plant.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .bold()
                        .font(Font.custom("OpenSans-Semibold", size: 35))
                    Spacer()
                    Image(systemName: "thermometer.variable")
                        .resizable()
                        .frame(width: 9, height: 18)
                        .foregroundStyle(plant.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                        .offset(y: -20)
                        .padding(.leading, 20)
                    Text("\(plant.temperature)°C")
                        .foregroundStyle(plant.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
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
                            .foregroundStyle(plant.colorCard == Color(.white) ? Color("ColorDarkGrey") : Color(.white))
                            .bold()
                    })
                    .animation(.snappy, value: isSilent)
                }
                .font(.subheadline)
                
                NavigationLink { PlantDetailView(plant: $plant, viewID: $viewID)
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
                    .background(plant.colorCard == Color(.white) ? Color("ColorCardPastelGreen") : Color(red: 239/255, green: 239/255, blue: 239/255))
                    .cornerRadius(10)
                }
            }
            Spacer()
        }
        .frame(height: isExpanded ? 280 : 130)
        .padding()
        .background(plant.colorCard)
        .cornerRadius(28)
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut, value: isExpanded)
        .padding(.horizontal)
    }
}


#Preview {
    @State var samplePlant = Plant(
        serverId: 1,
        name: "Фиалка",
        location: "Кухня",
        colorCard: Color("ColorCardLightGreen"),
        colorNumber: .white,
        colorCardCitcle: .colorDarkGrey,
        humidity: 21,
        temperature: 67
    )
    @State var samplePlants = [samplePlant]

    PlantCardView(
        plant: samplePlant,
        isExpanded: true,
        onTap: {}, plantStore: PlantStore(),
        viewID: .constant(UUID()), numberPlant: 1
    )
    PlantCardView(
        plant: samplePlant,
        isExpanded: false,
        onTap: {}, plantStore: PlantStore(),
        viewID: .constant(UUID()), numberPlant: 1
    )
}
