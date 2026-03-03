import SwiftUI
import Combine

/// 这是一个专门用于测试百炼 Agent API 是否通畅的调试页面。
/// 您可以直接在 Xcode 右侧的 Preview 中点击运行（Play 按钮）进行测试验证。
struct AiApiTesterView: View {
    // 请在这里贴入您真实的 API Key 和 App ID 进行测试
    @State private var apiKey = "sk-xxxxxxxx" // 您的百炼 API Key (形如 sk-...)
    @State private var appId = "a6211f0d197041eea8d243bcaaa6c527"   // 您的百炼应用 ID
    
    @State private var inputText = "你好，请自我介绍一下"
    
    @State private var isRequesting = false
    @State private var responseText = "点击发送测试..."
    @State private var httpStatusCode = ""
    @State private var rawJsonResponse = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("百炼 Agent API 连接测试")
                    .font(.title2.bold())
                
                Group {
                    Text("API Key (sk-...)")
                        .font(.caption)
                    TextField("sk-xxxx", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                    
                    Text("App ID")
                        .font(.caption)
                    TextField("App ID", text: $appId)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                    
                    Text("测试提示词")
                        .font(.caption)
                    TextField("输入测试内容", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: runTest) {
                    HStack {
                        Spacer()
                        if isRequesting {
                            ProgressView().tint(.white)
                            Text("请求中...")
                        } else {
                            Text("发送测试请求")
                        }
                        Spacer()
                    }
                    .padding()
                    .background(isRequesting ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRequesting || apiKey.isEmpty || appId.isEmpty)
                
                Divider().padding(.vertical)
                
                Text("状态码: \(httpStatusCode)")
                    .font(.headline)
                    .foregroundColor(httpStatusCode == "200" ? .green : .red)
                
                Text("解析的回复内容：")
                    .font(.headline)
                Text(responseText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                
                Text("原始 JSON 数据/错误信息：")
                    .font(.headline)
                ScrollView(.horizontal) {
                    Text(rawJsonResponse)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
            }
            .padding()
        }
    }
    
    // 独立的网络测试逻辑，完全照搬现有 AiChatService 的拼装格式
    private func runTest() {
        guard !apiKey.isEmpty, !appId.isEmpty, !inputText.isEmpty else { return }
        
        isRequesting = true
        responseText = ""
        httpStatusCode = "Loading..."
        rawJsonResponse = ""
        
        let urlString = "https://dashscope.aliyuncs.com/api/v1/apps/\(appId)/completion"
        guard let url = URL(string: urlString) else {
            responseText = "无效的 URL 格式"
            isRequesting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": [
                "messages": [
                    ["role": "user", "content": inputText]
                ]
            ],
            "parameters": [
                "incremental_output": false,
                "result_format": "message"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isRequesting = false
                
                if let error = error {
                    self.httpStatusCode = "Error"
                    self.rawJsonResponse = error.localizedDescription
                    self.responseText = "网络连接彻底失败：\(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self.httpStatusCode = "\(httpResponse.statusCode)"
                }
                
                guard let data = data else {
                    self.responseText = "未收到任何数据"
                    return
                }
                
                if let rawStr = String(data: data, encoding: .utf8) {
                    self.rawJsonResponse = rawStr
                }
                
                // 解析尝试
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let output = json["output"] as? [String: Any],
                       let choices = output["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        self.responseText = content
                    } else if let code = json["code"] as? String, let msg = json["message"] as? String {
                        self.responseText = "百炼接口报错：[\(code)] \(msg)"
                    } else {
                        self.responseText = "解析不出百炼的标准格式，请检查原始 JSON 字段"
                    }
                } else {
                    self.responseText = "JSON 反序列化失败"
                }
            }
        }.resume()
    }
}

#Preview {
    AiApiTesterView()
}
