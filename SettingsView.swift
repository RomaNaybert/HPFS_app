//
//  SettingsView.swift
//  HPFS
//
//  Created by Роман on 19.06.2025.
//

import SwiftUI

struct SettingsView: View {
    @Binding var selectedTabView: CustomTab
    var body: some View {
        ZStack {
            VStack{
                HStack {
                    Text("Настройки")
                        .font(Font.custom("OpenSans-Semibold", size: 33))
                        .kerning(-1.5)
                    Spacer()
                    Image("user_photo 1")
                }
                .padding(.horizontal, 30)
                SearchFieldView(selectedItem: .constant(2))
                    .padding(.vertical, 5)
            }
        }
            .background(Color(red: 239/255, green: 239/255, blue: 239/255))
    }
}


#Preview {
    SettingsView(selectedTabView: .constant(CustomTab.settings))
}
