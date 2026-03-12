import SwiftUI

enum ChatMessageType {
    case user
    case ai
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var content: String
    let type: ChatMessageType
    var isTyping: Bool
    let isStatusMessage: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        type: ChatMessageType,
        isTyping: Bool = false,
        isStatusMessage: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.isTyping = isTyping
        self.isStatusMessage = isStatusMessage
        self.createdAt = createdAt
    }
}
