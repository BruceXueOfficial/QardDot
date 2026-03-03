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
    @Published var pendingVoiceText: String = ""
    let aiService = AiChatService()
    private var cancellables = Set<AnyCancellable>()
    
    // Simulate generation abort token
    private var abortToken: UUID?

    init() {
        aiService.$isThinking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isThinking)
            
        speechManager.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                if self?.isRecording == true {
                    self?.pendingVoiceText = text
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
        messages.append(userMessage)
        inputText = ""
        isResponding = true
        
        let currentToken = UUID()
        abortToken = currentToken

        // Fetch from AI Service
        let history = messages.suffix(10).map { msg -> [String: String] in
            return [
                "role": msg.type == .user ? "user" : "assistant",
                "content": msg.content
            ]
        }
        
        aiService.sendMessage(messages: history) { [weak self] response in
            guard let self = self, self.abortToken == currentToken else { return }
            
            DispatchQueue.main.async {
                if let responseText = response {
                    self.processAiResponse(responseText, token: currentToken)
                } else {
                    self.isResponding = false
                }
            }
        }
    }
    
    func stopGeneration() {
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
    }
    
    // MARK: - Voice Actions
    
    func startVoiceRecording() {
        isRecording = true
        speechManager.startRecording()
    }
    
    func endVoiceRecording() {
        isRecording = false
        speechManager.stopRecording()
        
        // Let it settle slightly, then fetch transcribed text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let finalText = self.speechManager.recognizedText
            if !finalText.isEmpty {
                self.inputText = finalText
                self.sendMessage()
                self.speechManager.recognizedText = ""
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.pendingVoiceText = ""
            }
        }
    }
    
    func cancelVoiceRecording() {
        isRecording = false
        speechManager.cancelRecording()
        DispatchQueue.main.async { [weak self] in
            self?.pendingVoiceText = ""
        }
    }

    // MARK: - Simulation
    
    private func processAiResponse(_ fullText: String, token: UUID) {
        let separator = "#json"
        var displayText = fullText
        var jsonString: String? = nil
        
        if let range = fullText.range(of: separator) {
            displayText = String(fullText[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            jsonString = String(fullText[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Start typing effect for the display text
        startTypewriterEffect(token: token, fullText: displayText)
        
        // Try parsing JSON block into a KnowledgeCard
        if let jsonStr = jsonString, let data = jsonStr.data(using: .utf8) {
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
                print("Failed to parse #json: \(error)")
            }
        }
    }
    
    private func startTypewriterEffect(token: UUID, fullText: String) {
        let aiMessageId = UUID()
        let initialAiMessage = ChatMessage(id: aiMessageId, content: "", type: .ai, isTyping: true)
        messages.append(initialAiMessage)

        let characters = Array(fullText)
        var currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Abort Check
            if self.abortToken != token {
                timer.invalidate()
                return
            }

            if currentIndex < characters.count {
                if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    self.messages[index].content.append(characters[currentIndex])
                    currentIndex += 1
                } else {
                    timer.invalidate()
                }
            } else {
                if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    self.messages[index].isTyping = false
                }
                self.isResponding = false
                timer.invalidate()
            }
        }
    }
}
