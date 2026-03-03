import Foundation
import Combine

class AiChatService: ObservableObject {
    @Published var isThinking = false
    
    // 替换为您自己的 API 信息
    private let appId = "a6211f0d197041eea8d243bcaaa6c527"
    private var apiUrl: String { "https://dashscope.aliyuncs.com/api/v1/apps/\(appId)/completion" }
    private let apiKey = "sk-12a229305d114093a477cab30fedd02b"
    
    // 保存当前任务以便取消
    private var currentTask: URLSessionDataTask?
    
    func sendMessage(messages: [[String: String]], completion: @escaping (String?) -> Void) {
        guard let url = URL(string: apiUrl) else { return }
        
        DispatchQueue.main.async { self.isThinking = true }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": [
                "messages": messages
            ],
            "parameters": [
                "incremental_output": false,
                "result_format": "message"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // 每次发送前，取消上一次可能存在的请求
        currentTask?.cancel()
        
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async { self?.isThinking = false }
            
            if let error = error as NSError? {
                if error.code == NSURLErrorCancelled {
                    completion(nil)
                } else {
                    print("❌ Network error: \(error.localizedDescription)")
                    completion("网络请求失败：\(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response or data")
                completion(nil)
                return
            }
            
            print("🚀 API Response Status Code: \(httpResponse.statusCode)")
            if let text = String(data: data, encoding: .utf8) {
                print("📦 Raw Response Body: \(text)")
            }
            
            let responseText = self?.parseResponse(data: data)
            completion(responseText)
        }
        currentTask?.resume()
    }
    
    func cancelRequest() {
        if isThinking {
            currentTask?.cancel()
            DispatchQueue.main.async { self.isThinking = false }
        }
    }
    
    private func parseResponse(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any] else {
            return nil
        }
        
        if let choices = output["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        return output["text"] as? String
    }
}
