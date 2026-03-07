import SwiftUI
import Combine

class AiChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isResponding: Bool = false
    
    // AI Structured Data "Shopping Cart"
    @Published var recognizedCards: [KnowledgeCard] = []
    
    // Voice Handling
    @Published var isRecording: Bool = false
    let speechManager = ChatSpeechManager()
    
    // AI Service Integration
    @Published var isThinking: Bool = false
    let aiService = AiChatService()
    private var cancellables = Set<AnyCancellable>()
    
    // Simulate generation abort token
    private var abortToken: UUID?
    private var currentVoiceMessageID: UUID?

    init() {
        aiService.$isThinking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isThinking)
            
        speechManager.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self, self.isRecording, let id = self.currentVoiceMessageID else { return }
                if let idx = self.messages.firstIndex(where: { $0.id == id }) {
                    self.messages[idx].content = text.isEmpty ? "聆听中..." : text
                }
            }
            .store(in: &cancellables)
    }

    func clearMessages() {
        stopGeneration()
        withAnimation {
            messages.removeAll()
            inputText = ""
            recognizedCards.removeAll()
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(content: text, type: .user)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(userMessage)
        }
        inputText = ""
        isResponding = true
        
        triggerAI()
    }
    
    private func triggerAI() {
        let currentToken = UUID()
        abortToken = currentToken

        // Fetch from AI Service
        let history = messages.suffix(10).map { msg -> [String: String] in
            return [
                "role": msg.type == .user ? "user" : "assistant",
                "content": msg.content
            ]
        }
        
        let aiMessageId = UUID()
        
        // --- Typewriter State ---
        var networkBuffer: [Character] = []
        var displayedCharactersCount = 0
        var isStreamFinished = false
        var messageAdded = false
        var completedFullText: String? = nil
        
        // Create an intermediate buffer delay. We will wait 1.5s before typing starts.
        let typingStartTime = Date().addingTimeInterval(1.5)
        
        // Helper function to extract the required string cleanly
        func extractValidDisplayString(from text: String) -> String {
            var displayEndIndex = text.endIndex
            var jsonLowerBound = text.endIndex
            var hasJson = false
            
            if let jsonRange = text.range(of: "#json") {
                jsonLowerBound = jsonRange.lowerBound
                displayEndIndex = jsonRange.lowerBound
                hasJson = true
            }
            
            // Search for possible ending sentences from the Prompt
            let phrases = [
                "正在为您生成卡片。", "正在为您生成卡片",
                "正在为你输入卡片。", "正在为你输入卡片",
                "正在为你生成卡片。", "正在为你生成卡片",
                "生成卡片中", "生成卡片中。"
            ]
            
            var foundPhrase = false
            for phrase in phrases {
                if let msgRange = text.range(of: phrase) {
                    if msgRange.upperBound <= jsonLowerBound {
                        displayEndIndex = msgRange.upperBound
                        foundPhrase = true
                        break 
                    }
                }
            }
            
            var validText = String(text[..<displayEndIndex])
            
            // Fallback: if AI forgot to add the sentence before "#json", append it so the user sees it.
            if hasJson && !foundPhrase {
                let fallbackBlock = "\n\n正在为您生成卡片。"
                if !validText.hasSuffix("正在为您生成卡片。") {
                    validText += fallbackBlock
                }
            }
            
            return validText
        }
        
        // Set slightly slower FPS (12.5 FPS) to eliminate SwiftUI UI frame drop and blocking.
        // It's the only way to solve "chunking" or "stuck" frames.
        let t = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] t in
            guard let self = self, self.abortToken == currentToken else {
                t.invalidate()
                return
            }
            
            // Wait until 1.5s has passed to allow stream to buffer content
            guard Date() >= typingStartTime else { return }
            
            let bufferSize = networkBuffer.count - displayedCharactersCount
            if bufferSize > 0 {
                if !messageAdded {
                    let initialAiMessage = ChatMessage(id: aiMessageId, content: "", type: .ai, isTyping: true)
                    self.messages.append(initialAiMessage)
                    messageAdded = true
                }
                
                // Max limits amount to type per frame to ensure extreme smoothness!
                // 3 chars per 0.08s provides up to ~37.5 chars / sec. Fast but beautiful.
                let charsToType = min(bufferSize, 3)
                
                if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    let endIndex = min(displayedCharactersCount + charsToType, networkBuffer.count)
                    self.messages[index].content.append(contentsOf: networkBuffer[displayedCharactersCount..<endIndex])
                    displayedCharactersCount = endIndex
                } else {
                    t.invalidate()
                }
            } else if bufferSize < 0 {
                // The networkBuffer shrank because of trailing newline truncation when the final sentence was recognized.
                // We should sync the displayed content to the truncated buffer immediately to prevent the typing from skipping.
                if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    self.messages[index].content = String(networkBuffer)
                }
                displayedCharactersCount = networkBuffer.count
            } else if isStreamFinished {
                if messageAdded, let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    self.messages[index].isTyping = false
                    self.messages[index].content = self.messages[index].content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                self.isResponding = false
                t.invalidate()
                
                if let full = completedFullText {
                    self.processAiResponseEnd(fullText: full)
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        
        aiService.sendMessageStream(messages: history, onUpdate: { [weak self] partialText in
            guard let self = self, self.abortToken == currentToken else { return }
            
            let validText = extractValidDisplayString(from: partialText)
            networkBuffer = Array(validText)
            print("📥 [API Update received] New networkBuffer size: \(networkBuffer.count)")
            
        }, completion: { [weak self] fullText in
            guard let self = self, self.abortToken == currentToken else { return }
            
            print("🏁 [API Stream Complete]")
            DispatchQueue.main.async {
                completedFullText = fullText
                
                if let finalContent = fullText {
                    let validText = extractValidDisplayString(from: finalContent)
                    networkBuffer = Array(validText)
                }
                
                isStreamFinished = true
            }
        })
    }
    
    func stopGeneration(isInterrupt: Bool = false) {
        aiService.cancelRequest()
        abortToken = nil
        isResponding = false
        
        // Clean up last AI message if it was empty and interrupted
        if let last = messages.last, last.type == .ai, last.isTyping {
            var updated = last
            updated.isTyping = false
            if updated.content.isEmpty {
                messages.removeLast()
            } else {
                messages[messages.count - 1] = updated
            }
        }

        if isInterrupt {
            messages.append(ChatMessage(content: "🚫 已终止智能体输出", type: .ai, isTyping: false))
        }
    }
    
    // MARK: - Voice Actions
    
    func startVoiceRecording() {
        isRecording = true
        speechManager.startRecording()
        currentVoiceMessageID = UUID()
        let msg = ChatMessage(id: currentVoiceMessageID!, content: "聆听中...", type: .user)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(msg)
        }
    }
    
    func endVoiceRecording() {
        isRecording = false
        speechManager.stopRecording()
        
        // Let it settle slightly, then finalize the recognized text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let finalText = self.speechManager.recognizedText
            
            if !finalText.isEmpty {
                 if let id = self.currentVoiceMessageID, let idx = self.messages.firstIndex(where: { $0.id == id }) {
                     self.messages[idx].content = finalText
                 }
                 self.isResponding = true
                 self.triggerAI()
            } else {
                 if let id = self.currentVoiceMessageID {
                     withAnimation(.default) {
                         self.messages.removeAll(where: { $0.id == id })
                     }
                 }
            }
            self.speechManager.recognizedText = ""
            self.currentVoiceMessageID = nil
        }
    }
    
    func cancelVoiceRecording() {
        isRecording = false
        speechManager.cancelRecording()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let id = self.currentVoiceMessageID {
                withAnimation(.default) {
                    self.messages.removeAll(where: { $0.id == id })
                }
            }
            self.currentVoiceMessageID = nil
        }
    }

    // MARK: - Simulation
    
    private func processAiResponseEnd(fullText: String) {
        let separator = "#json"
        
        let components = fullText.components(separatedBy: separator)
        guard components.count > 1 else { return }
        
        for i in 1..<components.count {
            let jsonString = components[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let start = jsonString.firstIndex(of: "{"),
                  let end = jsonString.lastIndex(of: "}") else {
                continue
            }
            
            let cleanJson = String(jsonString[start...end])
            if let data = cleanJson.data(using: .utf8) {
                do {
                    let parsedDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    let title = parsedDict["title"] as? String ?? "未命名卡片"
                    
                    var blocks: [CardBlock] = []
                    if let modulesArray = parsedDict["modules"] as? [[String: Any]] {
                        for moduleDict in modulesArray {
                            let typeStr = moduleDict["type"] as? String ?? "text"
                            let mTitle = moduleDict["title"] as? String
                            let content = moduleDict["content"] as? String ?? ""
                            
                            switch typeStr {
                            case "text":
                                var block = CardBlock(kind: .text, text: content)
                                block.moduleTitle = mTitle
                                blocks.append(block)
                            case "formula":
                                var block = CardBlock(kind: .formula, text: content)
                                block.moduleTitle = mTitle
                                blocks.append(block)
                            case "link":
                                if let linksArray = moduleDict["links"] as? [[String: String]] {
                                    var linkItems: [LinkItem] = []
                                    for linkDict in linksArray {
                                        let url = linkDict["url"] ?? ""
                                        let lTitle = linkDict["title"] ?? "链接"
                                        linkItems.append(LinkItem(url: url, title: lTitle))
                                    }
                                    var block = CardBlock(kind: .link, linkItems: linkItems)
                                    block.moduleTitle = mTitle
                                    blocks.append(block)
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    let newCard = KnowledgeCard(
                        title: title,
                        content: "", // Content can be empty since we use modules
                        type: .long,
                        themeColor: .green,
                        modules: blocks.isEmpty ? nil : blocks
                    )
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.recognizedCards.append(newCard)
                    }
                } catch {
                    print("Failed to parse #json at index \(i): \(error)")
                }
            }
        }
    }
}
