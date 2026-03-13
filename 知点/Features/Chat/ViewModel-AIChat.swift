import SwiftUI
import Combine
import UIKit

private struct AiChatActiveResponse {
    let token: UUID
    let aiMessageID: UUID
    let typingStartTime: Date
    var networkBuffer: [Character] = []
    var displayedCharactersCount: Int = 0
    var isStreamFinished: Bool = false
    var messageAdded: Bool = false
    var completedFullText: String? = nil
}

class AiChatViewModel: ObservableObject {
    static let cardGenerationCompletionTemplates: [String] = [
        "已经为您生成 %d 张卡片，可点击左下角查看详情。",
        "本轮已为您整理出 %d 张卡片，可点击左下角查看详情。",
        "已根据刚才的对话生成 %d 张卡片，可点击左下角查看详情。",
        "卡片已经生成完成，本次共为您准备了 %d 张卡片，可点击左下角查看详情。",
        "已为您提炼出 %d 张卡片，可点击左下角查看详情。"
    ]

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isResponding: Bool = false
    @Published var sessionID: String = UUID().uuidString
    
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
    private var cardGenerationStatusTimer: Timer?
    private var responseTypingTimer: Timer?
    private var activeResponse: AiChatActiveResponse?
    private var isInBackground = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private static let responseTypingFrameInterval: TimeInterval = 0.08
    private static let responseTypingWarmupDelay: TimeInterval = 1.5
    private static let responseTypingCharactersPerSecond: Double = 37.5
    private static let responseTypingCharactersPerFrame = max(1, Int(round(responseTypingFrameInterval * responseTypingCharactersPerSecond)))

    static func cardGenerationCompletionMessage(cardCount: Int, randomIndex: Int? = nil) -> String {
        let templates = cardGenerationCompletionTemplates
        guard !templates.isEmpty else {
            return "已经为您生成 \(cardCount) 张卡片，可点击左下角查看详情。"
        }

        let resolvedIndex: Int
        if let randomIndex {
            resolvedIndex = min(max(randomIndex, 0), templates.count - 1)
        } else {
            resolvedIndex = Int.random(in: 0..<templates.count)
        }

        return String(format: templates[resolvedIndex], locale: Locale(identifier: "zh_CN"), cardCount)
    }

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

    deinit {
        responseTypingTimer?.invalidate()
        cardGenerationStatusTimer?.invalidate()
        endBackgroundTaskIfNeeded()
    }

    func clearMessages() {
        stopGeneration()
        withAnimation {
            messages.removeAll()
            inputText = ""
            recognizedCards.removeAll()
            sessionID = UUID().uuidString
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
        refreshBackgroundTaskState()
        
        triggerAI()
    }
    
    private func triggerAI() {
        cleanupResidualTypingMessages()

        let currentToken = UUID()
        abortToken = currentToken
        activeResponse = AiChatActiveResponse(
            token: currentToken,
            aiMessageID: UUID(),
            typingStartTime: Date().addingTimeInterval(Self.responseTypingWarmupDelay)
        )
        ensureResponseTypingTimer()

        // Fetch from AI Service using session_id
        let prompt = messages.last { $0.type == .user }?.content ?? ""
        
        aiService.sendMessageStream(prompt: prompt, sessionId: sessionID, onUpdate: { [weak self] partialText in
            guard let self = self, self.abortToken == currentToken else { return }
            
            let validText = Self.extractValidDisplayString(from: partialText)
            self.updateActiveResponse(for: currentToken) { response in
                response.networkBuffer = Array(validText)
            }
            self.syncActiveResponseTyping()
        }, completion: { [weak self] fullText in
            guard let self = self, self.abortToken == currentToken else { return }
            
            self.updateActiveResponse(for: currentToken) { response in
                response.completedFullText = fullText
                if let finalContent = fullText {
                    let validText = Self.extractValidDisplayString(from: finalContent)
                    response.networkBuffer = Array(validText)
                }
                response.isStreamFinished = true
            }
            self.syncActiveResponseTyping()
        })
    }
    
    func stopGeneration(isInterrupt: Bool = false) {
        aiService.cancelRequest()
        abortToken = nil
        activeResponse = nil
        isResponding = false
        cancelResponseTyping()
        cancelCardGenerationStatusTyping()
        refreshBackgroundTaskState()

        cleanupResidualTypingMessages()

        if isInterrupt {
            messages.append(
                ChatMessage(
                    content: "🚫 已终止智能体输出",
                    type: .ai,
                    isTyping: false,
                    isStatusMessage: true
                )
            )
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

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            isInBackground = false
            ensureResponseTypingTimer()
            syncActiveResponseTyping()
            refreshBackgroundTaskState()
        case .inactive:
            syncActiveResponseTyping()
        case .background:
            isInBackground = true
            ensureResponseTypingTimer()
            syncActiveResponseTyping()
            refreshBackgroundTaskState()
        @unknown default:
            break
        }
    }

    // MARK: - Simulation

    private func processAiResponseEnd(fullText: String) {
        let extractedCards = extractRecognizedCards(from: fullText)
        guard !extractedCards.isEmpty else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            recognizedCards.append(contentsOf: extractedCards)
        }

        let completionMessage = Self.cardGenerationCompletionMessage(cardCount: extractedCards.count)
        appendTypedCardGenerationStatusMessage(completionMessage)
    }

    private func appendTypedCardGenerationStatusMessage(_ content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        cancelCardGenerationStatusTyping()

        let statusMessageID = UUID()
        let characters = Array(trimmedContent)
        var displayedCharacterCount = 0

        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            messages.append(
                ChatMessage(
                    id: statusMessageID,
                    content: "",
                    type: .ai,
                    isTyping: true,
                    isStatusMessage: true
                )
            )
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard let index = self.messages.firstIndex(where: { $0.id == statusMessageID }) else {
                self.cancelCardGenerationStatusTyping()
                return
            }

            let nextCharacterCount = min(displayedCharacterCount + 2, characters.count)
            self.messages[index].content.append(contentsOf: characters[displayedCharacterCount..<nextCharacterCount])
            displayedCharacterCount = nextCharacterCount

            if displayedCharacterCount >= characters.count {
                self.messages[index].content = trimmedContent
                self.messages[index].isTyping = false
                self.cancelCardGenerationStatusTyping()
            }
        }

        cardGenerationStatusTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refreshBackgroundTaskState()
    }

    private func cancelCardGenerationStatusTyping() {
        cardGenerationStatusTimer?.invalidate()
        cardGenerationStatusTimer = nil
        refreshBackgroundTaskState()
    }

    private func extractRecognizedCards(from fullText: String) -> [KnowledgeCard] {
        let separator = "#json"
        let components = fullText.components(separatedBy: separator)
        guard components.count > 1 else { return [] }

        var extractedCards: [KnowledgeCard] = []

        for i in 1..<components.count {
            let jsonString = components[i].trimmingCharacters(in: .whitespacesAndNewlines)

            guard jsonString.contains("{") else {
                continue
            }

            do {
                var card = try ImportKnowledgeCardDecoder.decodeCard(from: jsonString)
                card.type = .long
                if card.themeColor == nil {
                    card.themeColor = .blue
                }
                extractedCards.append(card)
            } catch {
                print("Failed to parse #json at index \(i): \(error)")
            }
        }

        return extractedCards
    }

    private static func extractValidDisplayString(from text: String) -> String {
        var displayEndIndex = text.endIndex
        var jsonLowerBound = text.endIndex
        var hasJson = false

        if let jsonRange = text.range(of: "#json") {
            jsonLowerBound = jsonRange.lowerBound
            displayEndIndex = jsonRange.lowerBound
            hasJson = true
        }

        let phrases = [
            "正在为您生成卡片。", "正在为您生成卡片",
            "正在为你输入卡片。", "正在为你输入卡片",
            "正在为你生成卡片。", "正在为你生成卡片",
            "生成卡片中", "生成卡片中。"
        ]

        var foundPhrase = false
        for phrase in phrases {
            if let msgRange = text.range(of: phrase), msgRange.upperBound <= jsonLowerBound {
                displayEndIndex = msgRange.upperBound
                foundPhrase = true
                break
            }
        }

        var validText = String(text[..<displayEndIndex])

        if hasJson && !foundPhrase && !validText.hasSuffix("正在为您生成卡片。") {
            validText += "\n\n正在为您生成卡片。"
        }

        return validText
    }

    private func updateActiveResponse(
        for token: UUID,
        _ mutate: (inout AiChatActiveResponse) -> Void
    ) {
        guard var response = activeResponse, response.token == token else { return }
        mutate(&response)
        activeResponse = response
    }

    private func ensureResponseTypingTimer() {
        guard responseTypingTimer == nil, activeResponse != nil else { return }
        let timer = Timer(timeInterval: Self.responseTypingFrameInterval, repeats: true) { [weak self] _ in
            self?.syncActiveResponseTyping()
        }
        responseTypingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelResponseTyping() {
        responseTypingTimer?.invalidate()
        responseTypingTimer = nil
    }

    private func syncActiveResponseTyping(now: Date = Date()) {
        guard var response = activeResponse else {
            cancelResponseTyping()
            return
        }

        guard abortToken == response.token else {
            activeResponse = nil
            cancelResponseTyping()
            refreshBackgroundTaskState()
            return
        }

        let hasTypingStarted = now >= response.typingStartTime

        if hasTypingStarted && !response.networkBuffer.isEmpty {
            if !response.messageAdded {
                messages.append(ChatMessage(id: response.aiMessageID, content: "", type: .ai, isTyping: true))
                response.messageAdded = true
            }

            guard let index = messages.firstIndex(where: { $0.id == response.aiMessageID }) else {
                activeResponse = nil
                cancelResponseTyping()
                refreshBackgroundTaskState()
                return
            }

            let pendingCharacterCount = response.networkBuffer.count - response.displayedCharactersCount
            if pendingCharacterCount > 0 {
                let nextCharacterCount = min(
                    response.displayedCharactersCount + Self.responseTypingCharactersPerFrame,
                    response.networkBuffer.count
                )
                messages[index].content.append(
                    contentsOf: response.networkBuffer[response.displayedCharactersCount..<nextCharacterCount]
                )
                response.displayedCharactersCount = nextCharacterCount
            } else if pendingCharacterCount < 0 {
                messages[index].content = String(response.networkBuffer)
                response.displayedCharactersCount = response.networkBuffer.count
            }
        }

        let didFinishTyping = response.isStreamFinished && response.displayedCharactersCount >= response.networkBuffer.count
        if didFinishTyping {
            if response.messageAdded, let index = messages.firstIndex(where: { $0.id == response.aiMessageID }) {
                let finalizedDisplayText = String(response.networkBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
                if finalizedDisplayText.isEmpty {
                    messages.remove(at: index)
                } else {
                    messages[index].isTyping = false
                    messages[index].content = finalizedDisplayText
                }
            }

            let completedFullText = response.completedFullText
            activeResponse = nil
            cancelResponseTyping()
            isResponding = false
            refreshBackgroundTaskState()

            if let completedFullText {
                processAiResponseEnd(fullText: completedFullText)
            }
            return
        }

        activeResponse = response
    }

    private func cleanupResidualTypingMessages() {
        for index in messages.indices.reversed() where messages[index].type == .ai && messages[index].isTyping {
            let trimmedContent = messages[index].content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedContent.isEmpty {
                messages.remove(at: index)
            } else {
                messages[index].content = trimmedContent
                messages[index].isTyping = false
            }
        }
    }

    private var needsBackgroundExecution: Bool {
        isResponding || cardGenerationStatusTimer != nil
    }

    private func refreshBackgroundTaskState() {
        if isInBackground && needsBackgroundExecution {
            beginBackgroundTaskIfNeeded()
        } else {
            endBackgroundTaskIfNeeded()
        }
    }

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AiChatStreaming") { [weak self] in
            DispatchQueue.main.async {
                self?.syncActiveResponseTyping()
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
