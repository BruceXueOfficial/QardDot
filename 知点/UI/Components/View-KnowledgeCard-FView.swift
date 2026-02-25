import SwiftUI

// MARK: - Template Tokens

enum KnowledgeCardFViewTokens {
    static let surfaceHeight: CGFloat = 158

    static let splitLayout = ZDSplitCardLayout(
        cornerRadius: 14,
        topRatio: 0.30,
        contentPaddingTop: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 16),
        contentPaddingBottom: EdgeInsets(top: 6, leading: 12, bottom: 10, trailing: 6),
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 14, holeScale: 0.98),
        footerTopSpacerMin: 6
    )

    static let topFrost = ZDFrostRecipe(
        glassOpacity: 0.06,
        materialOpacity: 0.24,
        blurRadius: 1.1
    )

    static let bottomFrost = ZDFrostRecipe(
        glassOpacity: 0.16,
        materialOpacity: 0.34,
        blurRadius: 3.3
    )
}

// MARK: - KnowledgeCard-FView Template

struct KnowledgeCardFView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard

    private var theme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme)
    }

    private var questionAssetName: String {
        theme.recommendationQuestionAssetName
    }

    private var renderedContent: String {
        KnowledgeCardLViewContentResolver.recommendationExcerpt(for: card)
    }

    private var bodyTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.50)
    }

    private var titleTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.90)
    }

    private var tags: [String] {
        (card.tags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZDSplitGlassCard(
            layout: KnowledgeCardFViewTokens.splitLayout,
            palette: palette,
            topFrost: KnowledgeCardFViewTokens.topFrost,
            bottomFrost: KnowledgeCardFViewTokens.bottomFrost,
            questionAssetName: questionAssetName
        ) {
            Text(card.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleTextColor)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } body: {
            Text(renderedContent)
                .font(.subheadline)
                .foregroundStyle(bodyTextColor)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } footer: {
            HStack(spacing: 6) {
                if tags.isEmpty {
                    ZDCardTagChip(
                        text: "未添加标签",
                        textColor: palette.tagText,
                        backgroundColor: palette.tagBackground
                    )
                } else {
                    ForEach(Array(tags.prefix(2).enumerated()), id: \.offset) { _, tag in
                        ZDCardTagChip(
                            text: tag,
                            textColor: palette.tagText,
                            backgroundColor: palette.tagBackground
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: KnowledgeCardFViewTokens.surfaceHeight)
    }
}

private struct KnowledgeCardFViewPreviewPanel: View {
    let themes: [CardThemeColor]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(themes.enumerated()), id: \.offset) { index, theme in
                let card = KnowledgeCard(
                    title: "卡片标题卡片标题卡片标题",
                    content: """
                    ### 卡片正文卡片正文卡片正文
                    - 卡片正文卡片正文卡片正文
                    """,
                    tags: index % 2 == 0 ? ["Tag1", "Tag2"] : ["Tag1"],
                    themeColor: theme
                )

                KnowledgeCardFView(card: card)
            }
        }
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("KnowledgeCard-FView - Light") {
    KnowledgeCardFViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
}

#Preview("KnowledgeCard-FView - Dark") {
    KnowledgeCardFViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
}
