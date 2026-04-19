import Foundation
import Combine

class AiChatService: ObservableObject {
    @Published var isThinking = false
    
    // MARK: - 百炼 (Bailian / DashScope) Credentials
    private let bailianAppId = "a6211f0d197041eea8d243bcaaa6c527"
    private var bailianApiUrl: String { "https://dashscope.aliyuncs.com/api/v1/apps/\(bailianAppId)/completion" }
    private let bailianApiKey = "sk-12a229305d114093a477cab30fedd02b"
    
    // MARK: - Dify Credentials
    private let difyBaseUrl = "https://dify-uat.mcdonalds.cn/v1"
    private let difyApiKey = "app-jVk4umu2cPB05xR2wmGnzxDB"
    
    // MARK: - Dify Conversation Tracking
    /// Stores the Dify-assigned conversation_id for the current session.
    /// Empty string means "start a new conversation".
    private var difyConversationId: String = ""
    /// Tracks the last sessionId passed by the ViewModel, so we can detect
    /// when the user clears the conversation and starts fresh.
    private var lastDifySessionId: String = ""
    
    // MARK: - Stream Task
    private var streamTask: Task<Void, Never>?
    
    /// Reads the current provider selection from UserDefaults.
    private var currentProvider: AIProvider {
        let rawValue = UserDefaults.standard.string(forKey: AIProvider.storageKey)
            ?? AIProvider.defaultSelection.rawValue
        return AIProvider.resolve(rawValue: rawValue)
    }
    
    // MARK: - Public Interface
    
    func sendMessageStream(prompt: String, sessionId: String, onUpdate: @escaping (String) -> Void, completion: @escaping (String?) -> Void) {
        switch currentProvider {
        case .bailian:
            sendBailianStream(prompt: prompt, sessionId: sessionId, onUpdate: onUpdate, completion: completion)
        case .dify:
            sendDifyStream(prompt: prompt, sessionId: sessionId, onUpdate: onUpdate, completion: completion)
        }
    }
    
    // 兼容原有的协议
    func sendMessage(prompt: String, sessionId: String, completion: @escaping (String?) -> Void) {
        sendMessageStream(prompt: prompt, sessionId: sessionId, onUpdate: { _ in }) { result in
            completion(result)
        }
    }
    
    func cancelRequest() {
        if isThinking {
            streamTask?.cancel()
            DispatchQueue.main.async { self.isThinking = false }
        }
    }
    
    // MARK: - 百炼 Streaming Implementation
    
    private func sendBailianStream(prompt: String, sessionId: String, onUpdate: @escaping (String) -> Void, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: bailianApiUrl) else { return }
        
        DispatchQueue.main.async { self.isThinking = true }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bailianApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 增加流式相关的 Header
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-SSE")
        
        let body: [String: Any] = [
            "input": [
                "prompt": prompt,
                "session_id": sessionId
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
                    print("❌ 百炼: Invalid response or bad status code")
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
                    print("❌ 百炼 network error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isThinking = false
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Dify Streaming Implementation
    
    /// Whether the current Dify conversation has been warmed up.
    /// The Dify chatflow has a one-turn offset: the first message always
    /// gets a default "超出理解范围" reply, and the real answer appears on
    /// the second turn. We counteract this by sending an invisible warmup
    /// request before the user's first real message.
    private var difyConversationWarmedUp: Bool = false
    
    private func sendDifyStream(prompt: String, sessionId: String, onUpdate: @escaping (String) -> Void, completion: @escaping (String?) -> Void) {
        // Detect conversation reset: when the ViewModel generates a new sessionID
        // (e.g. after clearMessages), we discard the old Dify conversation_id
        // so the next request starts a brand-new conversation on Dify's side.
        if sessionId != lastDifySessionId {
            difyConversationId = ""
            difyConversationWarmedUp = false
            lastDifySessionId = sessionId
        }
        
        DispatchQueue.main.async { self.isThinking = true }
        
        // 每次发送前，取消上一次可能存在的请求
        streamTask?.cancel()
        
        streamTask = Task {
            // ── Warmup: silently consume the first offset turn ──
            if !difyConversationWarmedUp {
                print("🔄 Dify: Warming up new conversation...")
                let warmupConvId = await difyBlockingRequest(query: prompt)
                if Task.isCancelled { return }
                if let convId = warmupConvId {
                    self.difyConversationId = convId
                    self.difyConversationWarmedUp = true
                    print("✅ Dify: Warmup complete, conversation_id = \(convId)")
                } else {
                    print("⚠️ Dify: Warmup failed, proceeding without warmup")
                }
            }
            
            // ── Actual streaming request ──
            await difyStreamRequest(prompt: prompt, onUpdate: onUpdate, completion: completion)
        }
    }
    
    /// Sends a silent blocking request to Dify to initialize the conversation.
    /// Returns the conversation_id on success, nil on failure.
    private func difyBlockingRequest(query: String) async -> String? {
        guard let url = URL(string: "\(difyBaseUrl)/chat-messages") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(difyApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "inputs": [String: String](),
            "query": query,
            "response_mode": "blocking",
            "conversation_id": "",
            "user": AIProvider.persistentUserID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let convId = json["conversation_id"] as? String, !convId.isEmpty {
                return convId
            }
        } catch {
            print("❌ Dify warmup error: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Sends the actual streaming request to Dify and processes SSE events.
    private func difyStreamRequest(prompt: String, onUpdate: @escaping (String) -> Void, completion: @escaping (String?) -> Void) async {
        guard let url = URL(string: "\(difyBaseUrl)/chat-messages") else {
            DispatchQueue.main.async {
                self.isThinking = false
                completion(nil)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(difyApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "inputs": [String: String](),
            "query": prompt,
            "response_mode": "streaming",
            "conversation_id": difyConversationId,
            "user": AIProvider.persistentUserID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("❌ Dify: Bad status code \(httpResponse.statusCode)")
                } else {
                    print("❌ Dify: Invalid response")
                }
                DispatchQueue.main.async {
                    self.isThinking = false
                    completion(nil)
                }
                return
            }
            
            var fullContent = ""
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                
                // Dify SSE format:
                //   event: message
                //   data: {"event":"message","answer":"...","conversation_id":"...","message_id":"..."}
                // We only process `data:` lines; the event type is also inside the JSON payload.
                guard line.hasPrefix("data:") else { continue }
                
                let jsonStr = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonStr.isEmpty { continue }
                
                guard let data = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                let event = json["event"] as? String ?? ""
                
                // Capture conversation_id for memory continuity
                if let convId = json["conversation_id"] as? String, !convId.isEmpty {
                    self.difyConversationId = convId
                }
                
                switch event {
                case "message", "agent_message":
                    // Dify sends incremental `answer` chunks
                    if let answer = json["answer"] as? String, !answer.isEmpty {
                        fullContent += answer
                        let currentSnapshot = fullContent
                        DispatchQueue.main.async {
                            onUpdate(currentSnapshot)
                        }
                    }
                    
                case "message_end":
                    // Stream completed normally
                    break
                    
                case "error":
                    let errorMsg = json["message"] as? String ?? "Unknown error"
                    let errorCode = json["code"] as? String ?? ""
                    print("❌ Dify stream error [\(errorCode)]: \(errorMsg)")
                    break
                    
                default:
                    // Ignore other events: workflow_started, node_started, etc.
                    break
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
                print("❌ Dify network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isThinking = false
                    completion(nil)
                }
            }
        }
    }
}
