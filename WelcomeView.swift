//
//  RegistrationView.swift
//  HPFS
//
//  Created by Роман on 08.08.2025.
//

import SwiftUI

struct WelcomeView: View {
    
    @State private var plantNumber = 1
    @State private var currentScreen = 0// 0 - не нажат; 1 - вход; 2-3 - регистрация
    @State private var email = ""
    @State private var password = ""
    @State private var goHome = false
    @State private var goHomeLogin = false
    @State private var dragOffset: CGSize = .zero
    @EnvironmentObject var plantStore: PlantStore
    @StateObject var vm = AuthVM()
    @FocusState private var codeFieldFocused: Bool
    @EnvironmentObject var session: Session
    
    let y = UIScreen.main.bounds.width
    let x = UIScreen.main.bounds.height
    let h = UIScreen.main.bounds.width
    let w = UIScreen.main.bounds.height
    let contentAnim = Animation.easeInOut(duration: 1.5)
    
    var grayRectanglePosition: CGFloat {
        currentScreen != 0 ? UIScreen.main.bounds.height/1.6 : UIScreen.main.bounds.height*1.1
    }
    
    var timeInterval: Int {
        currentScreen == 0 ? 3 : 0
    }
    
    private func charAt(_ s: String, _ i: Int) -> String {
        guard i >= 0 && i < s.count else { return "" }
        let idx = s.index(s.startIndex, offsetBy: i)
        return String(s[idx])
    }
    
    var body: some View {
        
        NavigationStack{
            ZStack {
                // фон
                Color(hex: "D9D9D9").ignoresSafeArea()
                
                // слой с картинками (как у тебя было)
                Group {
                    Image("plantReg\(plantNumber)")
                        .resizable()
                        .frame(width: UIScreen.main.bounds.width/1.2,
                               height: UIScreen.main.bounds.height/1.2)
                        .position(x: UIScreen.main.bounds.width/2.4,
                                  y: UIScreen.main.bounds.height/2.3)
                    
                }
                .allowsHitTesting(false)
                ZStack {
                    Rectangle()
                        .clipShape(RoundedCorner(radius: 60, corners: .topRight))
                        .frame(width: UIScreen.main.bounds.width, height: h * 1.9)
                        .position(x: UIScreen.main.bounds.width / 2, y: grayRectanglePosition)
                        .foregroundStyle(Color(hex: "343434"))
                        .overlay(
                            Group {
                                if currentScreen == 0 {
                                    VStack {
                                        Spacer() // ← прижимает группу вниз
                                        VStack(spacing: 0) {
                                            VStack(spacing: -20) {
                                                Text("Добро")
                                                    .font(.custom("OpenSans-SemiBold", fixedSize: 43))
                                                    .foregroundStyle(.white)
                                                Text("пожаловать!")
                                                    .font(.custom("OpenSans-SemiBold", fixedSize: 43))
                                                    .foregroundStyle(.white)
                                            }
                                            .padding(.bottom, 50)
                                            
                                            VStack(spacing: 10) {
                                                Button { withAnimation(.easeInOut(duration: 0.5)) { currentScreen = 1 } } label: {
                                                    Rectangle()
                                                        .frame(width: 211, height: 36)
                                                        .foregroundStyle(Color(hex: "51945E"))
                                                        .cornerRadius(9)
                                                        .overlay {
                                                            Text("Войти в аккаунт")
                                                                .font(.custom("OpenSans-Regular", fixedSize: 14))
                                                                .foregroundStyle(.white)
                                                        }
                                                }
                                                Button { withAnimation(.easeInOut(duration: 0.5)) { currentScreen = 2 } } label: {
                                                    Text("Регистрация")
                                                        .font(.custom("OpenSans-Regular", fixedSize: 14))
                                                        .foregroundStyle(Color(hex: "51945E"))
                                                }
                                            }
                                        }
                                        .padding(.bottom, 50) // ← можно подрегулировать отступ от нижнего края
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)
                                    ))
                                } else if currentScreen == 1 {
                                    loginView
                                        .padding(.top, 170)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)
                                        ))
                                        .zIndex(1)
                                } else {
                                    regView
                                        .padding(.top, 180)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)
                                        ))
                                        .zIndex(1)
                                }
                            }
                            .animation(contentAnim, value: currentScreen)
                        )
                }
                // ВАЖНО: фиксированный фрейм для сцены панели
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: TimeInterval(timeInterval), repeats: currentScreen == 0) { _ in
                        if currentScreen == 0 {
                            
                            plantNumber = plantNumber % 3 + 1
                        } else {
                            plantNumber = 1
                        }
                    }
                }
            }
            .animation(.easeInOut.speed(0.3), value: plantNumber)
            .animation(.easeInOut.speed(0.3), value: currentScreen)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.startLocation.y < 1000 { // свайп от края
                            dragOffset = value.translation // сдвиг пальца от начальной точки
                        }
                    }
                    .onEnded { value in
                        if dragOffset.height > 60 {
                            withAnimation(.easeInOut(duration: 0.5)) { currentScreen = 0 }
                        } else {
                            dragOffset = .zero
                        }
                    }
            )
        }
        .environmentObject(PlantStore())
        .onAppear { vm.session = session }
    }
    
    @ViewBuilder
    private var loginView: some View {
        NavigationStack{
            VStack{
                ZStack{
                    VStack(alignment: .leading){
                        VStack(alignment: .leading, spacing: 4){
                            Text("Войти в аккаунт")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                            Text("Войти в существующий аккаунт")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans", size: 16))
                        }
                        Text("Почта")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 30)
                        ZStack(alignment: .leading){
                            TextField("", text: $vm.email)
                                .padding(.leading, 10)
                                .keyboardType(.emailAddress)
                                .frame(width: w/2.6)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(vm.email.isEmpty ? "Введите почту" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .allowsHitTesting(false)
                                .padding(.leading, 20)
                        }
                        Text("Пароль")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 20)
                        ZStack(alignment: .leading){
                            SecureField("", text: $vm.password)
                                .padding(.leading, 10)
                                .frame(width: w/2.6)
                                .textContentType(.password)
                                .privacySensitive(true)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(vm.password.isEmpty ? "Введите пароль" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .allowsHitTesting(false)
                                .padding(.leading, 20)
                        }
                        
                        HStack{
                            Button ( action: {
                                Task {
                                    await vm.login()
                                    if vm.stage == .done {
                                        withAnimation(.easeInOut(duration: 0.4)) { goHomeLogin = true }
                                    }
                                }
                            }, label: {
                                Rectangle()
                                    .frame(width: 107, height: 39)
                                    .foregroundStyle((!vm.email.isEmpty && !vm.password.isEmpty) ? Color(hex: "8EB87A") : Color(.colorDarkGrey))
                                    .cornerRadius(9)
                                    .overlay(
                                        Group {
                                            if vm.isLoggingIn {
                                                ProgressView().tint(.white)
                                            } else {
                                                Text("ВОЙТИ")
                                                    .foregroundStyle(.white)
                                                    .font(Font.custom("OpenSans-Semibold", size: 16))
                                            }
                                        }
                                    )
                                    .padding(.top, 15)
                            })
                            .disabled(vm.email.isEmpty || vm.password.isEmpty)
                            
                            
                            // Показ ошибок сервера, если есть
                            if let msg = vm.message, !msg.isEmpty {
                                Text(msg)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .font(Font.custom("OpenSans", size: 14))
                                    .padding(.top, 10)
                                    .padding(.leading, 10)
                            }
                        }
                    }
                    .position(x: x/4.3, y: y/2)
                }
                Image("plantAuth")
                    .resizable()
                    .frame(width: w/2.2, height: h/1.2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .position(x: x/4.3, y: y/2)
            }
        }
        .navigationDestination(isPresented: $goHomeLogin) {
                ContentView()
            }
    }
    
    @ViewBuilder
    private var regView: some View {
        VStack{
            ZStack{
                VStack(alignment: .leading){
                    VStack(alignment: .leading, spacing: 4){
                        VStack(alignment: .leading, spacing: -15){
                            Text(currentScreen == 3 ? "Лови письмо" : "Давай")
                                .foregroundStyle(.white)
                                .font(Font.custom("OpenSans-Semibold", size: 35))
                            if currentScreen != 3 {
                                Text("знакомиться")
                                    .foregroundStyle(.white)
                                    .font(Font.custom("OpenSans-Semibold", size: 35))
                            }
                        }
                        Text(currentScreen == 3 ? "Отправили код на \(vm.email)" : "Создать аккаунт в приложении")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 16))
                    }
                    if currentScreen == 2 {
                        Text("Почта")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 30)
                        ZStack(alignment: .leading){
                            TextField("", text: $vm.email)
                                .padding(.leading, 10)
                                .keyboardType(.emailAddress)
                                .frame(width: w/2.6)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(vm.email.isEmpty ? "Введите почту" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .allowsHitTesting(false)
                                .padding(.leading, 20)
                        }
                        Text("Пароль")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans-Semibold", size: 16))
                            .padding(.top, 20)
                        Text("Не менее 8 символов")
                            .foregroundStyle(.white)
                            .font(Font.custom("OpenSans", size: 12))
                            .padding(.bottom, 3)
                        ZStack(alignment: .leading){
                            SecureField("", text: $vm.password)
                                .padding(.leading, 10)
                                .frame(width: w/2.6)
                                .textContentType(.password)
                                .privacySensitive(true)
                                .padding(10)
                                .font(Font.custom("OpenSans", size: 16))
                                .background(Color(hex: "232323"))
                                .cornerRadius(9)
                                .foregroundStyle(Color(hex: "B2FF8D"))
                            Text(vm.password.isEmpty ? "Введите пароль" : " ")
                                .foregroundStyle(.white)
                                .opacity(0.7)
                                .allowsHitTesting(false)
                                .padding(.leading, 20)
                        }
                        
                        
                        // Условие активации кнопки
                        var isFormValid: Bool {
                            vm.email.contains("@") &&
                            vm.email.contains(".") &&
                            vm.password.count >= 8
                        }
                        
                        HStack{
                            
                            Button(action: {
                                Task {
                                    await vm.startRegistration()
                                    if vm.stage == .enterCode { // только если сервер сказал «ок»
                                                withAnimation(.easeInOut(duration: 0.5)) { currentScreen = 3 }
                                            }
                                }
                            }, label: {
                                Rectangle()
                                    .frame(width: 107, height: 39)
                                    .foregroundStyle(isFormValid ? Color(hex: "8EB87A") : Color(.colorDarkGrey))
                                    .animation(.easeInOut, value: isFormValid)
                                    .cornerRadius(9)
                                    .overlay(
                                                Group {
                                                    if vm.isStarting {
                                                        ProgressView().tint(.white)
                                                    } else {
                                                        Text("ДАЛЬШЕ")
                                                            .foregroundStyle(.white)
                                                            .font(Font.custom("OpenSans-Semibold", size: 16))
                                                    }
                                                }
                                            )
                                    .padding(.top, 15)
                            })
                            .disabled(!isFormValid)
                            .animation(.easeInOut(duration: 0.5), value: isFormValid)
                            
                            // Показ ошибок сервера, если есть
                            if let msg = vm.message, !msg.isEmpty {
                                Text(msg)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .font(Font.custom("OpenSans", size: 14))
                                    .padding(.leading, 10)
                                    .padding(.top, 10)
                            }
                        }
                    } else if currentScreen == 3 {
                        ZStack {
                            // 1) Невидимый TextField, но управляемый фокус
                            TextField("", text: $vm.code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .focused($codeFieldFocused)                 // <— ключевой момент
                                .frame(width: 1, height: 1)                 // 0x0 иногда ломает фокус, ставим 1x1
                                .opacity(0.01)
                                .onChange(of: vm.code) { newValue in
                                    vm.code = String(newValue.filter(\.isNumber).prefix(6))
                                    if vm.code.count == 6 {
                                        Task {
                                            await vm.verifyCode()
                                            if vm.stage == .done {
                                                withAnimation(.easeInOut(duration: 0.5)) { goHome = true }
                                            }
                                        }
                                    }
                                }

                            // 2) Фон
                            Rectangle()
                                .frame(width: w/2.5, height: h/1.5)
                                .cornerRadius(20)
                                .padding(.top, 20)
                                .foregroundStyle(Color(hex: "7CA06F"))

                            // 3) Ячейки кода
                            VStack{
                                HStack(spacing: 12) {
                                    ForEach(0..<6, id: \.self) { index in
                                        Rectangle()
                                            .overlay(
                                                Text(charAt(vm.code, index))      // безопасно достаём символ
                                                    .font(Font.custom("OpenSans", size: 35))
                                                    .foregroundStyle(Color(hex: "B2FF8D"))
                                            )
                                            .overlay(                              // подчёркиваем активную ячейку
                                                RoundedRectangle(cornerRadius: 15)
                                                    .stroke(index == vm.code.count ? Color.white.opacity(0.8) : .clear, lineWidth: 5)
                                            )
                                            .frame(width: w / 20, height: h / 6)
                                            .cornerRadius(15)
                                            .foregroundStyle(Color(hex: "232323"))
                                    }
                                }
                                if vm.stage == .done {
                                    NavigationLink(destination: ContentView()) {
                                        Rectangle()
                                            .frame(width: w/2.8, height: 39)
                                            .foregroundStyle(Color(.colorDarkGrey))
                                            .cornerRadius(9)
                                            .overlay(
                                                Text("ЗАВЕРШИТЬ РЕГИСТРАЦИЮ")
                                                    .foregroundStyle(.white)
                                                    .font(Font.custom("OpenSans-Semibold", size: 16))
                                            )
                                    }
                                    .offset(y: 40)
                                    .disabled(!goHome)

                                } else if vm.code.count == 0 {
                                    Button {
                                        Task { await vm.resend() }
                                    } label: {
                                        Rectangle()
                                            .frame(width: w/2.8, height: 39)
                                            .foregroundStyle(Color(.colorDarkGrey))
                                            .cornerRadius(9)
                                            .overlay(
                                                Text(vm.isResending ? "Отправляем..." : "Отправить код ещё раз")
                                                    .foregroundStyle(.white)
                                                    .font(Font.custom("OpenSans-Semibold", size: 16))
                                            )
                                    }
                                    .padding(.top, 16)
                                    .disabled(vm.isResending)
                                } else if vm.code.count != 0 || vm.stage != .done {
                                    if let msg = vm.message, !msg.isEmpty {
                                        Text(msg)
                                            .font(Font.custom("OpenSans", size: 14))
                                            .padding(.top, 8)
                                    }
                                }

                            }
                        }
                        .contentShape(Rectangle())           // кликабельно по всей области ZStack
                        .onTapGesture { codeFieldFocused = true }    // надёжно фокусим поле
                        .onAppear { codeFieldFocused = true }        // при открытии сразу фокус
                        .animation(.easeInOut, value: vm.code.count)
                    }
                }
                .position(x: x/4.3, y: y/2)
            }
            Image("plantAuth")
                .resizable()
                .frame(width: w/2.2, height: h/1.2)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .position(x: x/4.3, y: y/2)
        }
        .environmentObject(PlantStore())
    }

}


struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(Session())
}
