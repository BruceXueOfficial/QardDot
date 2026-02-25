import SwiftUI

// MARK: - Template Tokens

enum KnowledgeCardLViewTokens {
    static let bannerSize = CGSize(width: 252, height: 248)

    static let splitLayout = ZDSplitCardLayout(
        cornerRadius: 18,
        topRatio: 0.34,
        contentPaddingTop: EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 14),
        contentPaddingBottom: EdgeInsets(top: 12, leading: 12, bottom: 14, trailing: 14),
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.02)
    )

    static let topFrost = ZDFrostRecipe(
        glassOpacity: 0.025,
        materialOpacity: 0.07,
        blurRadius: 0.55
    )

    static let bottomFrost = ZDFrostRecipe(
        glassOpacity: 0.13,
        materialOpacity: 0.36,
        blurRadius: 3.8
    )
}

// MARK: - Content Resolver

enum KnowledgeCardLViewContentResolver {
    nonisolated static func firstTextBody(for card: KnowledgeCard) -> String {
        let modules = card.modules ?? card.blocks ?? []
        if let firstModuleText = modules
            .first(where: { $0.kind == .text })?
            .text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !firstModuleText.isEmpty {
            return firstModuleText
        }

        return card.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func recommendationExcerpt(for card: KnowledgeCard) -> String {
        let primaryText = firstTextBody(for: card)
        guard !primaryText.isEmpty else {
            return "点击查看完整卡片内容"
        }

        return cleanMarkdownMarkers(primaryText)
    }

    nonisolated private static func cleanMarkdownMarkers(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let cleanedLines = lines.map(stripMarkdownSyntax(in:))
        let merged = cleanedLines.joined(separator: "\n")
        let compactedNewlines = merged.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        let finalText = compactedNewlines.trimmingCharacters(in: .whitespacesAndNewlines)
        return finalText.isEmpty ? "点击查看完整卡片内容" : finalText
    }

    nonisolated private static func stripMarkdownSyntax(in rawLine: String) -> String {
        var line = rawLine

        line = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s*"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\s{0,3}>\s*"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\s{0,3}(?:[-+*])\s+\[[ xX]\]\s+"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\s{0,3}(?:[-+*])\s+"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\s{0,3}\d+[.)]\s+"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\s{0,3}```.*$"#, with: "", options: .regularExpression)

        if line.range(of: #"^\s*([-*_]\s*){3,}$"#, options: .regularExpression) != nil {
            return ""
        }

        line = line.replacingOccurrences(of: #"\!\[([^\]]*)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"`([^`]*)`"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"~~(.+?)~~"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"(?:\*\*|__)(.+?)(?:\*\*|__)"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"(?:\*|_)(.+?)(?:\*|_)"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"</?[^>]+>"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\\([\\`*_{}\[\]()#+\-.!>])"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\s*\|\s*"#, with: " ", options: .regularExpression)

        return line.trimmingCharacters(in: .whitespaces)
    }
}

private enum KnowledgeCardLViewShadowTuning {
    static let baseLightOpacity: Double = 0.09
    static let baseDarkOpacity: Double = 0.24
    static let baseLightRadius: CGFloat = 5
    static let baseDarkRadius: CGFloat = 7
    static let baseLightY: CGFloat = 4
    static let baseDarkY: CGFloat = 5

    static let tintLightOpacity: Double = 0.10
    static let tintDarkOpacity: Double = 0.24
    static let tintLightRadius: CGFloat = 3
    static let tintDarkRadius: CGFloat = 4
    static let tintY: CGFloat = 2
}

// MARK: - KnowledgeCard-LView Template

struct KnowledgeCardLView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard
    let viewCount: Int

    private var theme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme)
    }

    private var tags: [String] {
        (card.tags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var renderedContent: String {
        KnowledgeCardLViewContentResolver.recommendationExcerpt(for: card)
    }

    private var bodyTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.50)
    }

    var body: some View {
        ZDSplitGlassCard(
            layout: KnowledgeCardLViewTokens.splitLayout,
            palette: palette,
            topFrost: KnowledgeCardLViewTokens.topFrost,
            bottomFrost: KnowledgeCardLViewTokens.bottomFrost
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if tags.isEmpty {
                    ZDCardTagChip(
                        text: "未添加标签",
                        textColor: palette.tagText,
                        backgroundColor: palette.tagBackground
                    )
                } else {
                    ZDCardAdaptiveTagChipRow(
                        tags: tags,
                        chipTextColor: palette.tagText,
                        chipBackgroundColor: palette.tagBackground,
                        overflowTextColor: palette.metaText,
                        trailingReservedWidth: 34
                    )
                }

                Text(card.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.titleText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("knowledgeSquare.recommendation.top")
        } body: {
            Text(renderedContent)
                .font(.subheadline)
                .foregroundStyle(bodyTextColor)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("knowledgeSquare.recommendation.body")
        } footer: {
            HStack(spacing: 10) {
                Label("\(viewCount)", systemImage: "eye.fill")
                Spacer(minLength: 8)
                Text(card.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.metaText)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("knowledgeSquare.recommendation.footer")
        }
        .frame(
            width: KnowledgeCardLViewTokens.bannerSize.width,
            height: KnowledgeCardLViewTokens.bannerSize.height
        )
        .accessibilityIdentifier("knowledgeSquare.recommendation.card")
        .shadow(
            color: Color.black.opacity(
                colorScheme == .dark
                    ? KnowledgeCardLViewShadowTuning.baseDarkOpacity
                    : KnowledgeCardLViewShadowTuning.baseLightOpacity
            ),
            radius: colorScheme == .dark
                ? KnowledgeCardLViewShadowTuning.baseDarkRadius
                : KnowledgeCardLViewShadowTuning.baseLightRadius,
            x: 0,
            y: colorScheme == .dark
                ? KnowledgeCardLViewShadowTuning.baseDarkY
                : KnowledgeCardLViewShadowTuning.baseLightY
        )
        .shadow(
            color: theme.primaryColor.opacity(
                colorScheme == .dark
                    ? KnowledgeCardLViewShadowTuning.tintDarkOpacity
                    : KnowledgeCardLViewShadowTuning.tintLightOpacity
            ),
            radius: colorScheme == .dark
                ? KnowledgeCardLViewShadowTuning.tintDarkRadius
                : KnowledgeCardLViewShadowTuning.tintLightRadius,
            x: 0,
            y: KnowledgeCardLViewShadowTuning.tintY
        )
    }
}

private struct KnowledgeCardLViewPreviewGallery: View {
    let themes: [CardThemeColor]

    var body: some View {
        ZStack {
            Color.zdPageBase.ignoresSafeArea()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(themes) { theme in
                        let card = KnowledgeCard(
                            title: "为什么维生素C可以增强抵抗力？",
                            content: "维生素 C 可促进胶原蛋白合成，并且作为抗氧化剂参与免疫反应。",
                            tags: ["营养", "健康"],
                            themeColor: theme,
                            modules: [
                                CardBlock(
                                    kind: .text,
                                    moduleTitle: "正文",
                                    text: "维生素 C 可促进胶原蛋白合成，并且作为抗氧化剂参与免疫反应。"
                                )
                            ]
                        )

                        KnowledgeCardLView(card: card, viewCount: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }
}

#Preview("KnowledgeCard-LView Themes - Light") {
    KnowledgeCardLViewPreviewGallery(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
}

#Preview("KnowledgeCard-LView Themes - Dark") {
    KnowledgeCardLViewPreviewGallery(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
}
