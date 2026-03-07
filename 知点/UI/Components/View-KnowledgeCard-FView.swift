import SwiftUI

// MARK: - Template Tokens

enum KnowledgeCardFViewTokens {
    static let surfaceHeight: CGFloat = 158

    static let splitLayout = ZDSplitCardLayout(
        cornerRadius: 18,
        topRatio: 0.30,
        contentPaddingTop: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 16),
        contentPaddingBottom: EdgeInsets(top: 6, leading: 12, bottom: 10, trailing: 6),
        // Align punch-hole size/inset with LView while keeping FView's own corner radius.
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.312),
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
    @Environment(\.zdListRenderProfile) private var renderProfile

    let card: KnowledgeCard

    private var theme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme, renderMode: renderProfile.mode)
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
                .foregroundStyle(palette.titleText)
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

#Preview("KnowledgeCard-FView Themes - 性能优先（Light）") {
    KnowledgeCardFViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
        .environment(\.zdListRenderMode, .performance)
}

#Preview("KnowledgeCard-FView Themes - 性能优先（Dark）") {
    KnowledgeCardFViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
        .environment(\.zdListRenderMode, .performance)
}

private struct KnowledgeCardFViewModePreview: View {
    let mode: ZDListRenderMode

    private var sampleCard: KnowledgeCard {
        KnowledgeCard(
            title: "Git 中的 Push 命令是什么？",
            content: "git push 会把本地分支提交同步到远程仓库，常用于团队协作。",
            tags: ["Git", "编程"],
            themeColor: .blue
        )
    }

    var body: some View {
        ZStack {
            Color.zdPageBase.ignoresSafeArea()
            KnowledgeCardFView(card: sampleCard)
        }
        .padding()
        .environment(\.zdListRenderMode, mode)
    }
}

#Preview("KnowledgeCard-FView - 视效优先") {
    KnowledgeCardFViewModePreview(mode: .visual)
        .preferredColorScheme(.light)
}

#Preview("KnowledgeCard-FView - 性能优先") {
    KnowledgeCardFViewModePreview(mode: .performance)
        .preferredColorScheme(.light)
}
