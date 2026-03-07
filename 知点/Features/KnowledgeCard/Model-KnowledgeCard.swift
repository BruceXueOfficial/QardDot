import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct KnowledgeCard: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date

    var title: String
    // Legacy text field kept for backward compatibility.
    var content: String
    // Legacy card type kept for backward compatibility.
    var type: CardType

    // Legacy short-card fields kept for backward compatibility.
    var images: [String]?
    var codeSnippets: [CodeSnippet]?
    var links: [LinkItem]?
    var tags: [String]?
    var themeColor: CardThemeColor?

    // Unified module source.
    var modules: [CardBlock]?
    // Legacy long-card field kept for backward compatibility.
    var blocks: [CardBlock]?

    // Linked card references (card-to-card relationships).
    var linkedCardIDs: [UUID]?

    // Resolved theme colors (not stored, computed)
    var resolvedPrimary: Color { (themeColor ?? .defaultTheme).primaryColor }
    var resolvedSecondary: Color { (themeColor ?? .defaultTheme).secondaryColor }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String,
        content: String,
        type: CardType = .short,
        images: [String]? = nil,
        codeSnippets: [CodeSnippet]? = nil,
        links: [LinkItem]? = nil,
        tags: [String]? = nil,
        themeColor: CardThemeColor? = nil,
        modules: [CardBlock]? = nil,
        blocks: [CardBlock]? = nil,
        linkedCardIDs: [UUID]? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.content = content
        self.type = type
        self.images = images
        self.codeSnippets = codeSnippets
        self.links = links
        self.tags = tags
        self.themeColor = themeColor
        self.modules = modules ?? blocks
        self.blocks = blocks ?? modules
        self.linkedCardIDs = linkedCardIDs
    }

    mutating func touchUpdatedAt() {
        updatedAt = Date()
    }
}

enum CardType: String, Codable, CaseIterable {
    case short
    case long

    var title: String {
        "知识卡片"
    }
}

enum CardThemeColor: String, Codable, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case purple

    var id: String { rawValue }

    nonisolated static let defaultTheme: CardThemeColor = .blue

    nonisolated static var allCases: [CardThemeColor] {
        [.blue, .green, .orange, .purple]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let raw else {
            self = .defaultTheme
            return
        }

        switch raw {
        case "blue", "nightblue":
            self = .blue
        case "green", "aqua", "nightteal", "mint", "forestnight":
            self = .green
        case "orange":
            self = .orange
        case "purple", "mist", "graphite":
            self = .purple
        default:
            self = .defaultTheme
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .blue:
            "蓝"
        case .green:
            "绿"
        case .orange:
            "橙"
        case .purple:
            "紫"
        }
    }

    func prefersLightForeground(in colorScheme: ColorScheme) -> Bool {
        colorScheme == .dark
    }

    var primaryColor: Color {
        switch self {
        case .blue:
            Self.dynamicColor(lightHex: 0x0052D4, darkHex: 0x003A99)
        case .green:
            Self.dynamicColor(lightHex: 0x008A27, darkHex: 0x00661A)
        case .orange:
            Self.dynamicColor(lightHex: 0xE65C00, darkHex: 0xCC4400)
        case .purple:
            Self.dynamicColor(lightHex: 0x6100E6, darkHex: 0x4700B3)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .blue:
            Self.dynamicColor(lightHex: 0x0088FF, darkHex: 0x0066CC)
        case .green:
            Self.dynamicColor(lightHex: 0x00C23A, darkHex: 0x00992B)
        case .orange:
            Self.dynamicColor(lightHex: 0xFF9500, darkHex: 0xE67300)
        case .purple:
            Self.dynamicColor(lightHex: 0xA233FF, darkHex: 0x7A00E6)
        }
    }

    var fillPrimaryColor: Color {
        switch self {
        case .blue:
            Self.dynamicColor(lightHex: 0xEAF5FF, darkHex: 0x1A2E4C)
        case .green:
            Self.dynamicColor(lightHex: 0xECFAEF, darkHex: 0x194025)
        case .orange:
            Self.dynamicColor(lightHex: 0xFFF3EA, darkHex: 0x4C2915)
        case .purple:
            Self.dynamicColor(lightHex: 0xF5EDFF, darkHex: 0x331E54)
        }
    }

    var fillSecondaryColor: Color {
        switch self {
        case .blue:
            Self.dynamicColor(lightHex: 0xF2F9FF, darkHex: 0x203A60)
        case .green:
            Self.dynamicColor(lightHex: 0xF3FCF5, darkHex: 0x1E4F2E)
        case .orange:
            Self.dynamicColor(lightHex: 0xFFF7F1, darkHex: 0x59311A)
        case .purple:
            Self.dynamicColor(lightHex: 0xF9F4FF, darkHex: 0x43276B)
        }
    }

    // 标签折叠视图顶部：左侧折叠块主色（更深）
    var tagFolderTopDeepColor: Color {
        switch self {
        case .blue:
            Color(uiColor: UIColor(hex: 0x21396C))
        case .green:
            Color(uiColor: UIColor(hex: 0x1C543F))
        case .orange:
            Color(uiColor: UIColor(hex: 0x6A411E))
        case .purple:
            Color(uiColor: UIColor(hex: 0x31276E))
        }
    }

    // 标签折叠视图顶部：右侧背景块主色（更浅）
    var tagFolderTopLightColor: Color {
        switch self {
        case .blue:
            Color(uiColor: UIColor(hex: 0x31508E))
        case .green:
            Color(uiColor: UIColor(hex: 0x2B6B52))
        case .orange:
            Color(uiColor: UIColor(hex: 0x8B5428))
        case .purple:
            Color(uiColor: UIColor(hex: 0x493A96))
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [fillPrimaryColor, fillSecondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardBackgroundStyle: AnyShapeStyle {
        AnyShapeStyle(cardBackgroundGradient)
    }

    var cardBorderGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor.opacity(0.8), secondaryColor.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func dynamicColor(lightHex: Int, darkHex: Int) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(hex: darkHex)
                    : UIColor(hex: lightHex)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

struct CodeSnippet: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var language: String
    var code: String

    init(
        id: UUID = UUID(),
        name: String = "Untitled Snippet",
        language: String,
        code: String
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.code = code
    }
}

struct LinkItem: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var previewImageURL: String?
    var previewDescription: String?

    init(
        id: UUID = UUID(),
        url: String,
        title: String,
        previewImageURL: String? = nil,
        previewDescription: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.previewImageURL = previewImageURL
        self.previewDescription = previewDescription
    }
}

struct CardBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: CardBlockKind
    var moduleTitle: String?
    var text: String?
    var imageURL: String?
    var imageURLs: [String]?
    var codeSnippet: CodeSnippet?
    var codeSnippets: [CodeSnippet]?
    var linkItem: LinkItem?
    var linkItems: [LinkItem]?

    init(
        id: UUID = UUID(),
        kind: CardBlockKind,
        moduleTitle: String? = nil,
        text: String? = nil,
        imageURL: String? = nil,
        imageURLs: [String]? = nil,
        codeSnippet: CodeSnippet? = nil,
        codeSnippets: [CodeSnippet]? = nil,
        linkItem: LinkItem? = nil,
        linkItems: [LinkItem]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.moduleTitle = moduleTitle
        self.text = text
        let normalizedImages = Self.normalizedImageSources(imageURLs: imageURLs, fallback: imageURL)
        self.imageURLs = normalizedImages.isEmpty ? nil : normalizedImages
        self.imageURL = normalizedImages.first
        let normalizedCodeSnippets = Self.normalizedCodeSnippets(
            codeSnippets: codeSnippets,
            fallback: codeSnippet
        )
        self.codeSnippets = normalizedCodeSnippets.isEmpty ? nil : normalizedCodeSnippets
        self.codeSnippet = normalizedCodeSnippets.first
        if let items = linkItems, !items.isEmpty {
            self.linkItems = items
            self.linkItem = items.first
        } else if let linkItem {
            self.linkItems = [linkItem]
            self.linkItem = linkItem
        } else {
            self.linkItems = nil
            self.linkItem = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, moduleTitle, text, imageURL, imageURLs, codeSnippet, codeSnippets, linkItem, linkItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(CardBlockKind.self, forKey: .kind)
        moduleTitle = try container.decodeIfPresent(String.self, forKey: .moduleTitle)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        let decodedImageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        let decodedImageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs)
        let normalizedImages = Self.normalizedImageSources(
            imageURLs: decodedImageURLs,
            fallback: decodedImageURL
        )
        imageURLs = normalizedImages.isEmpty ? nil : normalizedImages
        imageURL = normalizedImages.first
        let decodedCodeSnippet = try container.decodeIfPresent(CodeSnippet.self, forKey: .codeSnippet)
        let decodedCodeSnippets = try container.decodeIfPresent([CodeSnippet].self, forKey: .codeSnippets)
        let normalizedCodeSnippets = Self.normalizedCodeSnippets(
            codeSnippets: decodedCodeSnippets,
            fallback: decodedCodeSnippet
        )
        codeSnippets = normalizedCodeSnippets.isEmpty ? nil : normalizedCodeSnippets
        codeSnippet = normalizedCodeSnippets.first

        let decodedItems = try container.decodeIfPresent([LinkItem].self, forKey: .linkItems)
        let decodedSingle = try container.decodeIfPresent(LinkItem.self, forKey: .linkItem)

        if let decodedItems, !decodedItems.isEmpty {
            linkItems = decodedItems
            linkItem = decodedItems.first
        } else if let decodedSingle {
            linkItems = [decodedSingle]
            linkItem = decodedSingle
        } else {
            linkItems = nil
            linkItem = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(moduleTitle, forKey: .moduleTitle)
        try container.encodeIfPresent(text, forKey: .text)
        let normalizedImages = Self.normalizedImageSources(imageURLs: imageURLs, fallback: imageURL)
        if !normalizedImages.isEmpty {
            try container.encode(normalizedImages, forKey: .imageURLs)
            try container.encode(normalizedImages.first, forKey: .imageURL)
        }
        let normalizedCodeSnippets = Self.normalizedCodeSnippets(
            codeSnippets: codeSnippets,
            fallback: codeSnippet
        )
        if !normalizedCodeSnippets.isEmpty {
            try container.encode(normalizedCodeSnippets, forKey: .codeSnippets)
            try container.encode(normalizedCodeSnippets.first, forKey: .codeSnippet)
        }

        if let linkItems, !linkItems.isEmpty {
            try container.encode(linkItems, forKey: .linkItems)
            try container.encode(linkItems.first, forKey: .linkItem)
        } else {
            try container.encodeIfPresent(linkItem, forKey: .linkItem)
        }
    }

    static func text(_ text: String) -> CardBlock {
        CardBlock(kind: .text, text: text)
    }

    static func image(_ imageURL: String, moduleTitle: String? = nil) -> CardBlock {
        CardBlock(kind: .image, moduleTitle: moduleTitle, imageURL: imageURL, imageURLs: [imageURL])
    }

    static func images(_ imageURLs: [String], moduleTitle: String? = nil) -> CardBlock {
        CardBlock(kind: .image, moduleTitle: moduleTitle, imageURLs: imageURLs)
    }

    static func code(_ snippet: CodeSnippet) -> CardBlock {
        CardBlock(kind: .code, codeSnippet: snippet, codeSnippets: [snippet])
    }

    static func codes(_ snippets: [CodeSnippet], moduleTitle: String? = nil) -> CardBlock {
        CardBlock(kind: .code, moduleTitle: moduleTitle, codeSnippets: snippets)
    }

    static func link(_ item: LinkItem) -> CardBlock {
        CardBlock(kind: .link, linkItem: item, linkItems: [item])
    }

    static func links(_ items: [LinkItem], moduleTitle: String? = nil) -> CardBlock {
        CardBlock(
            kind: .link,
            moduleTitle: moduleTitle,
            linkItem: items.first,
            linkItems: items
        )
    }

    static func formula(_ latex: String, moduleTitle: String? = nil) -> CardBlock {
        CardBlock(kind: .formula, moduleTitle: moduleTitle, text: latex)
    }

    private static func normalizedImageSources(imageURLs: [String]?, fallback: String?) -> [String] {
        let normalized = (imageURLs ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !normalized.isEmpty {
            return normalized
        }
        let fallbackNormalized = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fallbackNormalized.isEmpty ? [] : [fallbackNormalized]
    }

    private static func normalizedCodeSnippets(
        codeSnippets: [CodeSnippet]?,
        fallback: CodeSnippet?
    ) -> [CodeSnippet] {
        if let codeSnippets, !codeSnippets.isEmpty {
            return codeSnippets
        }
        if let fallback {
            return [fallback]
        }
        return []
    }
}

enum CardBlockKind: String, Codable, CaseIterable {
    case text
    case image
    case code
    case link
    case formula
    case linkedCard

    var displayName: String {
        switch self {
        case .text:
            return "总结"
        case .image:
            return "图片"
        case .code:
            return "代码"
        case .link:
            return "链接"
        case .formula:
            return "公式"
        case .linkedCard:
            return "关联卡片"
        }
    }
}

// MARK: - Preview Data
extension KnowledgeCard {
    static var previewShort: KnowledgeCard {
        KnowledgeCard(
            title: "SwiftUI MVVM 架构模式",
            content: """
            MVVM (Model-View-ViewModel) 是 SwiftUI 推荐的架构模式。

            - **Model**: 数据源，负责存储数据。
            - **View**: 声明式 UI，负责展示数据。
            - **ViewModel**: 连接层，负责处理业务逻辑。

            > 下方展示了一个基础的代码实现案例。
            """,
            type: .short,
            images: [
                "https://images.unsplash.com/photo-1516116216624-53e697fedbea?auto=format&fit=crop&w=1400&q=80",
                "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?auto=format&fit=crop&w=1400&q=80",
                "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&w=1400&q=80"
            ],
            codeSnippets: [
                CodeSnippet(
                    name: "ViewModel 实现",
                    language: "Swift",
                    code: """
                    class ViewModel: ObservableObject {
                        @Published var data: String = ""

                        func fetchData() {
                            // Network request...
                        }
                    }
                    """
                )
            ],
            links: [
                LinkItem(
                    url: "https://developer.apple.com/documentation/swiftui",
                    title: "SwiftUI 官方文档",
                    previewDescription: "Apple Developer Documentation"
                )
            ],
            tags: ["SwiftUI", "架构", "iOS"]
        )
    }
}
