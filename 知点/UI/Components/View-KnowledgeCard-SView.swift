import SwiftUI

// MARK: - Template Tokens

enum KnowledgeCardSViewTokens {
    static let surfaceHeight: CGFloat = 110

    static let splitLayout = ZDSplitCardLayout(
        cornerRadius: 14,
        topRatio: 0.675,
        contentPaddingTop: EdgeInsets(top: 10, leading: 10, bottom: 8, trailing: 14),
        contentPaddingBottom: EdgeInsets(top: 5, leading: 10, bottom: 8, trailing: 10),
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 14, holeScale: 0.98),
        footerTopSpacerMin: 0
    )

    static let topFrost = ZDFrostRecipe(
        glassOpacity: 0.08,
        materialOpacity: 0.26,
        blurRadius: 1.2
    )

    static let bottomFrost = ZDFrostRecipe(
        glassOpacity: 0.14,
        materialOpacity: 0.34,
        blurRadius: 3.2
    )
}

// MARK: - KnowledgeCard-SView Template

struct KnowledgeCardSView: View {
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

    private var renderedDate: String {
        card.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var metaTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.58)
    }

    private var tags: [String] {
        (card.tags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZDSplitGlassCard(
            layout: KnowledgeCardSViewTokens.splitLayout,
            palette: palette,
            topFrost: KnowledgeCardSViewTokens.topFrost,
            bottomFrost: KnowledgeCardSViewTokens.bottomFrost,
            questionAssetName: questionAssetName
        ) {
            Text(card.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.titleText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } body: {
            EmptyView()
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

                Spacer(minLength: 4)

                Text(renderedDate)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(metaTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(height: KnowledgeCardSViewTokens.surfaceHeight)
    }
}

private struct KnowledgeCardSViewPreviewPanel: View {
    let themes: [CardThemeColor]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(themes.enumerated()), id: \.offset) { index, theme in
                let card = KnowledgeCard(
                    title: "卡片标题",
                    content: """
                    ### Content of the QardCard
                    - Content of the QardCard
                    > Content of the QardCard
                    *Content of the QardCard*
                    """,
                    tags: index % 2 == 0 ? ["Tag1", "Tag2"] : ["Tag1"],
                    themeColor: theme
                )

                KnowledgeCardSView(card: card)
            }
        }
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("KnowledgeCard-SView - Light") {
    KnowledgeCardSViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
}

#Preview("KnowledgeCard-SView - Dark") {
    KnowledgeCardSViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
}

#Preview("KnowledgeCard-SView Themes - 性能优先（Light）") {
    KnowledgeCardSViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
        .environment(\.zdListRenderMode, .performance)
}

#Preview("KnowledgeCard-SView Themes - 性能优先（Dark）") {
    KnowledgeCardSViewPreviewPanel(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
        .environment(\.zdListRenderMode, .performance)
}

private struct KnowledgeCardSViewModePreview: View {
    let mode: ZDListRenderMode

    private var sampleCard: KnowledgeCard {
        KnowledgeCard(
            title: "Git 中的 Add 命令是什么？",
            content: "git add 用于把工作区变更放入暂存区，为下一次提交做准备。",
            tags: ["Git", "编程"],
            themeColor: .blue
        )
    }

    var body: some View {
        ZStack {
            Color.zdPageBase.ignoresSafeArea()
            KnowledgeCardSView(card: sampleCard)
        }
        .padding()
        .environment(\.zdListRenderMode, mode)
    }
}

#Preview("KnowledgeCard-SView - 视效优先") {
    KnowledgeCardSViewModePreview(mode: .visual)
        .preferredColorScheme(.light)
}

#Preview("KnowledgeCard-SView - 性能优先") {
    KnowledgeCardSViewModePreview(mode: .performance)
        .preferredColorScheme(.light)
}
