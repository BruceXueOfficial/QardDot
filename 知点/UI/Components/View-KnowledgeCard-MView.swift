import SwiftUI

// MARK: - Template Tokens

enum KnowledgeCardMViewTokens {
    static let surfaceSize = CGSize(width: 220, height: 160)

    static let splitLayout = ZDSplitCardLayout(
        cornerRadius: 18,
        topRatio: 0.70,
        contentPaddingTop: EdgeInsets(top: 12, leading: 14, bottom: 8, trailing: 24),
        contentPaddingBottom: EdgeInsets(top: 4, leading: 14, bottom: 18, trailing: 14),
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.0),
        footerTopSpacerMin: 0
    )

    // Match LView glass recipe to keep split colors visually identical.
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

private enum KnowledgeCardMViewShadowTuning {
    static let baseLightOpacity: Double = 0.09
    static let baseDarkOpacity: Double = 0.24
    static let baseLightRadius: CGFloat = 5
    static let baseDarkRadius: CGFloat = 7
    static let baseLightY: CGFloat = 4
    static let baseDarkY: CGFloat = 5

    static let tintLightOpacity: Double = 0.12
    static let tintDarkOpacity: Double = 0.22
    static let tintLightRadius: CGFloat = 3
    static let tintDarkRadius: CGFloat = 4
    static let tintY: CGFloat = 2
}

// MARK: - KnowledgeCard-MView Template

struct KnowledgeCardMView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard
    let viewCount: Int

    private var theme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    private var questionAssetName: String {
        theme.recommendationQuestionAssetName
    }

    private var cleanedBodyText: String {
        KnowledgeCardLViewContentResolver.recommendationExcerpt(for: card)
    }

    private var bodyTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.50)
    }

    private var metaTextColor: Color {
        swappedPalette.metaText
    }

    private var tagSummary: String {
        let normalized = (card.tags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if normalized.isEmpty {
            return "未添加标签"
        }
        return normalized.joined(separator: "；")
    }

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme)
    }

    private var swappedPalette: ZDSplitCardPalette {
        ZDSplitCardPalette(
            topFill: palette.bottomFill,
            bottomFill: palette.topFill,
            border: palette.border,
            questionGradient: palette.questionGradient,
            tagBackground: palette.tagBackground,
            tagText: palette.tagText,
            titleText: palette.titleText,
            bodyText: palette.bodyText,
            metaText: palette.metaText,
            divider: palette.divider
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZDSplitGlassCard(
                layout: KnowledgeCardMViewTokens.splitLayout,
                palette: swappedPalette,
                topFrost: KnowledgeCardMViewTokens.topFrost,
                bottomFrost: KnowledgeCardMViewTokens.bottomFrost,
                questionAssetName: questionAssetName
            ) {
                Text(cleanedBodyText)
                    .font(.subheadline)
                    .foregroundStyle(bodyTextColor)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .accessibilityIdentifier("knowledgeSquare.recent.mview.body")
            } body: {
                EmptyView()
            } footer: {
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                        Text("查看 \(viewCount)")
                            .monospacedDigit()
                    }

                    Spacer(minLength: 8)

                    Text(card.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(metaTextColor)
                .accessibilityIdentifier("knowledgeSquare.recent.mview.footer")
            }
            .frame(
                width: KnowledgeCardMViewTokens.surfaceSize.width,
                height: KnowledgeCardMViewTokens.surfaceSize.height
            )
            .accessibilityIdentifier("knowledgeSquare.recent.mview.surface")
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark
                        ? KnowledgeCardMViewShadowTuning.baseDarkOpacity
                        : KnowledgeCardMViewShadowTuning.baseLightOpacity
                ),
                radius: colorScheme == .dark
                    ? KnowledgeCardMViewShadowTuning.baseDarkRadius
                    : KnowledgeCardMViewShadowTuning.baseLightRadius,
                x: 0,
                y: colorScheme == .dark
                    ? KnowledgeCardMViewShadowTuning.baseDarkY
                    : KnowledgeCardMViewShadowTuning.baseLightY
            )
            .shadow(
                color: theme.primaryColor.opacity(
                    colorScheme == .dark
                        ? KnowledgeCardMViewShadowTuning.tintDarkOpacity
                        : KnowledgeCardMViewShadowTuning.tintLightOpacity
                ),
                radius: colorScheme == .dark
                    ? KnowledgeCardMViewShadowTuning.tintDarkRadius
                    : KnowledgeCardMViewShadowTuning.tintLightRadius,
                x: 0,
                y: KnowledgeCardMViewShadowTuning.tintY
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.96))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(tagSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: KnowledgeCardMViewTokens.surfaceSize.width, alignment: .leading)
    }
}

private struct KnowledgeCardMViewPreviewGallery: View {
    let themes: [CardThemeColor]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(Array(themes.enumerated()), id: \.offset) { index, theme in
                    let card = KnowledgeCard(
                        title: "卡片标题卡片标题卡片标题...",
                        content: """
                        ### Content of the QardCard
                        - Content of the QardCard
                        > Content of the QardCard
                        *Content of the QardCard*
                        """,
                        tags: ["标签1", "标签2"],
                        themeColor: theme
                    )

                    KnowledgeCardMView(card: card, viewCount: 25 + index * 7)
                }
            }
            .padding()
        }
        .background(Color.zdPageBase)
    }
}

#Preview("KnowledgeCard-MView - Light") {
    KnowledgeCardMViewPreviewGallery(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
}

#Preview("KnowledgeCard-MView - Dark") {
    KnowledgeCardMViewPreviewGallery(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
}
