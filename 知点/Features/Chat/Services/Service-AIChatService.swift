import Foundation
import Combine

class AiChatService: ObservableObject {
    @Published var isThinking = false
    
    // 替换为您自己的 API 信息
    private let appId = "a6211f0d197041eea8d243bcaaa6c527"
    private var apiUrl: String { "https://dashscope.aliyuncs.com/api/v1/apps/\(appId)/completion" }
    private let apiKey = "sk-12a229305d114093a477cab30fedd02b"
    
    // 替换原有的 currentTask 为 streamTask
    private var streamTask: Task<Void, Never>?
    
    func sendMessageStream(messages: [[String: String]], onUpdate: @escaping (String) -> Void, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: apiUrl) else { return }
        
        DispatchQueue.main.async { self.isThinking = true }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 增加流式相关的 Header
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-SSE")
        
        let body: [String: Any] = [
            "input": [
                "messages": messages
            ],
            "parameters": [
                "incremental_output": true,
                "result_format": "message"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // 每次发送前，取消上一次可能存在的请求
        streamTask?.cancel()
        
        streamTask = Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("❌ Invalid response or bad status code")
                    DispatchQueue.main.async {
                        self.isThinking = false
                        completion(nil)
                    }
                    return
                }
                
                var fullContent = ""
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    
                    if line.hasPrefix("data:") {
                        let jsonStr = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
                        if jsonStr.isEmpty { continue }
                        
                        if let data = jsonStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let output = json["output"] as? [String: Any] {
                            
                            var incrementalText = ""
                            if let choices = output["choices"] as? [[String: Any]],
                               let message = choices.first?["message"] as? [String: Any],
                               let contentChunk = message["content"] as? String {
                                incrementalText = contentChunk
                            } else if let textChunk = output["text"] as? String {
                                incrementalText = textChunk
                            }
                            
                            if !incrementalText.isEmpty {
                                fullContent += incrementalText
                                let currentSnapshot = fullContent
                                DispatchQueue.main.async {
                                    onUpdate(currentSnapshot)
                                }
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.isThinking = false
                    if Task.isCancelled {
                        completion(nil)
                    } else {
                        completion(fullContent.isEmpty ? nil : fullContent)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ Network error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isThinking = false
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // 兼容原有的协议
    func sendMessage(messages: [[String: String]], completion: @escaping (String?) -> Void) {
        sendMessageStream(messages: messages, onUpdate: { _ in }) { result in
            completion(result)
        }
    }
    
    func cancelRequest() {
        if isThinking {
            streamTask?.cancel()
            DispatchQueue.main.async { self.isThinking = false }
        }
    }
}
