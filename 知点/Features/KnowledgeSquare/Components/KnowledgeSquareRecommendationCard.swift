import SwiftUI
import UIKit

enum KnowledgeSquareCardContentResolver {
    static func firstTextBody(for card: KnowledgeCard) -> String {
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

    static func recommendationExcerpt(for card: KnowledgeCard) -> AttributedString {
        let primaryText = firstTextBody(for: card)
        guard !primaryText.isEmpty else {
            return AttributedString("点击查看完整卡片内容")
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: primaryText, options: options))
            ?? AttributedString(primaryText)
    }
}

private enum KnowledgeSquareRecommendationShadowTuning {
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

struct KnowledgeSquareRecommendationCard: View {
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

    private var renderedContent: AttributedString {
        KnowledgeSquareCardContentResolver.recommendationExcerpt(for: card)
    }

    var body: some View {
        ZDSplitGlassCard(
            layout: ZDCardStyleTokens.recommendationSplitLayout,
            palette: palette,
            topFrost: ZDCardStyleTokens.recommendationTopFrost,
            bottomFrost: ZDCardStyleTokens.recommendationBottomFrost
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if tags.isEmpty {
                    Text("未添加标签")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.tagText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.tagBackground)
                        .clipShape(Capsule())
                } else {
                    KnowledgeSquareAdaptiveTagChipRow(
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
                .foregroundStyle(palette.bodyText)
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
            width: ZDCardStyleTokens.recommendationBannerSize.width,
            height: ZDCardStyleTokens.recommendationBannerSize.height
        )
        .accessibilityIdentifier("knowledgeSquare.recommendation.card")
        .shadow(
            color: Color.black.opacity(
                colorScheme == .dark
                    ? KnowledgeSquareRecommendationShadowTuning.baseDarkOpacity
                    : KnowledgeSquareRecommendationShadowTuning.baseLightOpacity
            ),
            radius: colorScheme == .dark
                ? KnowledgeSquareRecommendationShadowTuning.baseDarkRadius
                : KnowledgeSquareRecommendationShadowTuning.baseLightRadius,
            x: 0,
            y: colorScheme == .dark
                ? KnowledgeSquareRecommendationShadowTuning.baseDarkY
                : KnowledgeSquareRecommendationShadowTuning.baseLightY
        )
        .shadow(
            color: theme.primaryColor.opacity(
                colorScheme == .dark
                    ? KnowledgeSquareRecommendationShadowTuning.tintDarkOpacity
                    : KnowledgeSquareRecommendationShadowTuning.tintLightOpacity
            ),
            radius: colorScheme == .dark
                ? KnowledgeSquareRecommendationShadowTuning.tintDarkRadius
                : KnowledgeSquareRecommendationShadowTuning.tintLightRadius,
            x: 0,
            y: KnowledgeSquareRecommendationShadowTuning.tintY
        )
    }
}

private struct KnowledgeSquareAdaptiveTagChipRow: View {
    let tags: [String]
    let chipTextColor: Color
    let chipBackgroundColor: Color
    let overflowTextColor: Color
    let trailingReservedWidth: CGFloat

    private let chipFont = UIFont.systemFont(ofSize: 10, weight: .medium)
    private let overflowFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
    private let chipHorizontalPadding: CGFloat = 16
    private let chipSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let result = fittingResult(for: max(0, proxy.size.width - trailingReservedWidth))
            HStack(spacing: chipSpacing) {
                ForEach(Array(result.visibleTags.enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(chipTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(chipBackgroundColor)
                        .clipShape(Capsule())
                }

                if result.hiddenCount > 0 {
                    Text("+\(result.hiddenCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(overflowTextColor)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 24)
    }

    private func fittingResult(for availableWidth: CGFloat) -> (visibleTags: [String], hiddenCount: Int) {
        guard !tags.isEmpty, availableWidth > 0 else {
            return ([], tags.count)
        }

        let tagWidths = tags.map(measuredChipWidth(for:))
        let totalWidth = rowWidth(tagWidths: tagWidths, hiddenCount: 0)
        if totalWidth <= availableWidth {
            return (tags, 0)
        }

        var bestVisibleCount = 0
        for visibleCount in 0...tags.count {
            let hiddenCount = tags.count - visibleCount
            let visibleWidths = Array(tagWidths.prefix(visibleCount))
            let candidateWidth = rowWidth(tagWidths: visibleWidths, hiddenCount: hiddenCount)
            if candidateWidth <= availableWidth {
                bestVisibleCount = visibleCount
            } else {
                break
            }
        }

        return (
            visibleTags: Array(tags.prefix(bestVisibleCount)),
            hiddenCount: max(0, tags.count - bestVisibleCount)
        )
    }

    private func rowWidth(tagWidths: [CGFloat], hiddenCount: Int) -> CGFloat {
        guard !tagWidths.isEmpty || hiddenCount > 0 else { return 0 }

        let tagsWidth = tagWidths.reduce(0, +)
        let tagsSpacing = CGFloat(max(tagWidths.count - 1, 0)) * chipSpacing
        if hiddenCount == 0 {
            return tagsWidth + tagsSpacing
        }

        let overflowText = "+\(hiddenCount)" as NSString
        let overflowSize = overflowText.size(withAttributes: [.font: overflowFont])
        let overflowSpacing = tagWidths.isEmpty ? 0 : chipSpacing
        return tagsWidth + tagsSpacing + overflowSpacing + ceil(overflowSize.width)
    }

    private func measuredChipWidth(for text: String) -> CGFloat {
        let value = text as NSString
        let textSize = value.size(withAttributes: [.font: chipFont])
        return ceil(textSize.width) + chipHorizontalPadding
    }
}

private struct KnowledgeSquareRecommendationPreviewGallery: View {
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

                        KnowledgeSquareRecommendationCard(card: card, viewCount: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }
}

#Preview("Recommendation Themes - Light") {
    KnowledgeSquareRecommendationPreviewGallery(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.light)
}

#Preview("Recommendation Themes - Dark") {
    KnowledgeSquareRecommendationPreviewGallery(themes: [.blue, .green, .orange, .purple])
        .preferredColorScheme(.dark)
}
