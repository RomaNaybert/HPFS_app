import SwiftUICore
import SwiftUI
//
//struct LayeredCardView: View {
//    let plant: Plant
//    let index: Int
//    let scrollOffset: CGFloat
//    let totalCount: Int
//    let cardHeight: CGFloat = 130
//    let overlapHeight: CGFloat = 50
//
//    var body: some View {
//        let yOffset = max(0, scrollOffset - CGFloat(index) * (cardHeight - overlapHeight))
//
//        return PlantCardView(
//            plant: plant,
//            isExpanded: false,
//            onTap: {}, plants: $plants
//        )
//        .offset(y: yOffset)
//        .zIndex(Double(totalCount - index))
//        .animation(.easeInOut(duration: 0.2), value: scrollOffset)
//    }
//}
//
//struct CardOffsetKey: PreferenceKey {
//    static var defaultValue: [Int: CGFloat] = [:]
//    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
//        value.merge(nextValue()) { $1 }
//    }
//}
//
//struct LayeredCardStackView: View {
//    let plants: [Plant]
//    @State private var scrollOffset: CGFloat = 0
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: -50) {
//                GeometryReader { geo in
//                    Color.clear
//                        .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
//                        .frame(height: 0)
//                }
//
//                ForEach(Array(plants.enumerated()), id: \.offset) { index, plant in
//                    LayeredCardView(
//                        plant: plant,
//                        index: index,
//                        scrollOffset: scrollOffset,
//                        totalCount: plants.count
//                    )
//                }
//            }
//            .padding(.top, 300)
//            .background(GeometryReader { _ in Color.clear })
//        }
//        .coordinateSpace(name: "scroll")
//        .onPreferenceChange(ScrollOffsetKey.self) { value in
//            self.scrollOffset = -value
//        }
//    }
//}
//
//struct ScrollOffsetKey: PreferenceKey {
//    static var defaultValue: CGFloat = 0
//    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
//        value += nextValue()
//    }
//}
//


import SwiftUI

import SwiftUI

struct KandinskyImageView: View {
    @State private var prompt: String = "Зелёное растение в горшке"
    @State private var width: String = "512"
    @State private var height: String = "512"
    @State private var style: String = "DEFAULT"
    @State private var generatedImage: UIImage? = nil
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    
    private let apiKey = "74CA2CC4488AD199B69963998E1947EE"
    private let secretKey = "6DAEDB220BC0599F8B23829667820B02"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Промт", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                HStack {
                    TextField("Ширина", text: $width)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    TextField("Высота", text: $height)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                .padding(.horizontal)

                TextField("Стиль (например, ANIME)", text: $style)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button(action: generateImage) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(isGenerating ? "Генерация..." : "Сгенерировать")
                    }
                }
                .disabled(isGenerating)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                if let uiImage = generatedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .padding()
                }

                if let error = errorMessage {
                    Text("Ошибка: \(error)")
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .navigationTitle("Kandinsky 3.1")
            .background(.gray)
        }
        .background(.gray)
    }
    
    private func generateImage() {
        isGenerating = true
        errorMessage = nil
        generatedImage = nil
        
        guard let widthInt = Int(width), let heightInt = Int(height) else {
            errorMessage = "Неверные значения ширины или высоты"
            isGenerating = false
            return
        }

        let query = prompt
        let modelURL = URL(string: "https://api-key.fusionbrain.ai/key/api/v1/pipelines")!
        
        var request = URLRequest(url: modelURL)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "X-Key")
        request.setValue("Secret \(secretKey)", forHTTPHeaderField: "X-Secret")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let models = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let pipelineId = models.first?["id"] as? String else {
                DispatchQueue.main.async {
                    errorMessage = "Ошибка получения модели"
                    isGenerating = false
                }
                return
            }

            submitPrompt(to: pipelineId, query: query, width: widthInt, height: heightInt)
        }.resume()
    }
    
    private func submitPrompt(to pipelineId: String, query: String, width: Int, height: Int) {
        let generateURL = URL(string: "https://api-key.fusionbrain.ai/key/api/v1/pipeline/run")!
        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "X-Key")
        request.setValue("Secret \(secretKey)", forHTTPHeaderField: "X-Secret")

        let params: [String: Any] = [
            "type": "GENERATE",
            "style": style,
            "width": width,
            "height": height,
            "numImages": 1,
            "generateParams": [
                "query": query
            ]
        ]
        
        let paramsData = try! JSONSerialization.data(withJSONObject: params, options: [])
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"pipeline_id\"\r\n\r\n")
        body.append("\(pipelineId)\r\n")
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"params\"\r\n")
        body.append("Content-Type: application/json\r\n\r\n")
        body.append(paramsData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data,
                  let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let uuid = response["uuid"] as? String else {
                DispatchQueue.main.async {
                    errorMessage = "Ошибка генерации изображения"
                    isGenerating = false
                }
                return
            }

            checkStatus(uuid: uuid)
        }.resume()
    }

    private func checkStatus(uuid: String) {
        let statusURL = URL(string: "https://api-key.fusionbrain.ai/key/api/v1/pipeline/status/\(uuid)")!
        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "X-Key")
        request.setValue("Secret \(secretKey)", forHTTPHeaderField: "X-Secret")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = response["status"] as? String else {
                DispatchQueue.main.async {
                    errorMessage = "Ошибка проверки статуса"
                    isGenerating = false
                }
                return
            }

            if status == "DONE",
               let result = response["result"] as? [String: Any],
               let files = result["files"] as? [String],
               let imageUrlString = files.first {

                print("DEBUG: Image Base64 = \(imageUrlString.prefix(30))...") // Укорачиваем для логов

                if let imageData = Data(base64Encoded: imageUrlString),
                   let image = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        self.generatedImage = image
                        self.isGenerating = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Не удалось декодировать изображение"
                        self.isGenerating = false
                    }
                }

            } else if status == "PROCESSING" || status == "INITIAL" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.checkStatus(uuid: uuid)
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Не удалось сгенерировать изображение"
                    self.isGenerating = false
                }
            }
        }.resume()
    }
}

// MARK: - Data append for multipart
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
