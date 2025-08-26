//
//  SearchFieldView.swift
//  HPFS
//
//  Created by Роман on 27.04.2025.
//

import SwiftUI

struct SearchFieldView: View {
    @State var textSearch: String = ""
    @State private var isKeyboardVisible = false
    @Binding var selectedItem: Int
    
    
    var body: some View {
        ZStack{
            Rectangle()
                .frame(width: UIScreen.main.bounds.width/1.15, height: 37)
                .cornerRadius(10)
                .foregroundStyle(Color("ColorDarkGrey"))
                .ignoresSafeArea()
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(.white))
                .bold()
                .padding(.leading, -160)
            TextField(" ", text: $textSearch)
                .foregroundStyle(Color(.white))
                .padding(.leading, 110)
            if textSearch.isEmpty {
                if selectedItem == 0{
                    Text("Найти растение")
                        .padding(.leading, -70)
                        .foregroundStyle(Color(.white))
                        .opacity(0.6)
                        .font(Font.custom("OpenSans-Semibold", size: 20))
                        .allowsHitTesting(false)
                        .frame(width: 355, height: 37)
                } else if selectedItem == 1 {
                    Text("Найти устройство")
                        .padding(.leading, -50)
                        .foregroundStyle(Color(.white))
                        .opacity(0.6)
                        .font(Font.custom("OpenSans-Semibold", size: 20))
                        .allowsHitTesting(false)
                        .frame(width: 355, height: 37)
                } else {
                    Text("Найти параметр")
                        .padding(.leading, -65)
                        .foregroundStyle(Color(.white))
                        .opacity(0.6)
                        .font(Font.custom("OpenSans-Semibold", size: 20))
                        .allowsHitTesting(false)
                        .frame(width: 355, height: 37)
                }
            }
        }
        .padding(.bottom, isKeyboardVisible ? 30 : 0)
        .animation(.easeInOut, value: isKeyboardVisible)
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
        .ignoresSafeArea(.all)
    }
}

#Preview {
    SearchFieldView(selectedItem: .constant(0))
    SearchFieldView(selectedItem: .constant(1))
    SearchFieldView(selectedItem: .constant(2))
}
