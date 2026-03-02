import SwiftUI
import Combine

class AiChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isResponding: Bool = false
    
    // Voice Handling
    @Published var isRecording: Bool = false
    let speechManager = ChatSpeechManager()
    
    // Simulate generation abort token
    private var abortToken: UUID?

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

        // Simulate network/typing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.abortToken == currentToken else { return }
            self.simulateAIResponse(token: currentToken)
        }
    }
    
    func stopGeneration() {
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
            if !self.speechManager.recognizedText.isEmpty {
                self.inputText = self.speechManager.recognizedText
                self.sendMessage()
                self.speechManager.recognizedText = ""
            }
        }
    }
    
    func cancelVoiceRecording() {
        isRecording = false
        speechManager.cancelRecording()
    }

    // MARK: - Simulation
    
    private func simulateAIResponse(token: UUID) {
        let aiMessageId = UUID()
        let initialAiMessage = ChatMessage(id: aiMessageId, content: "", type: .ai, isTyping: true)
        messages.append(initialAiMessage)

        let mockResponse = "功能开发中，敬请期待。"
        let characters = Array(mockResponse)
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
