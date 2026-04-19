import Foundation

/// Represents the AI service provider used for chat conversations.
enum AIProvider: String, CaseIterable, Identifiable {
    case bailian = "bailian"
    case dify = "dify"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bailian: return "百炼"
        case .dify: return "Dify"
        }
    }

    var detail: String {
        switch self {
        case .bailian: return "阿里云百炼大模型工作流，通义千问驱动"
        case .dify: return "Dify 工作流编排对话平台，支持记忆上下文"
        }
    }

    static let storageKey = "ai_provider_selection"
    static let defaultSelection: AIProvider = .bailian

    static func resolve(rawValue: String) -> AIProvider {
        AIProvider(rawValue: rawValue) ?? .defaultSelection
    }

    /// A stable, persistent user identifier for API calls that require a `user` field.
    static var persistentUserID: String {
        let key = "ai_persistent_user_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newID = "qd-ios-\(UUID().uuidString.prefix(8).lowercased())"
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }
}
