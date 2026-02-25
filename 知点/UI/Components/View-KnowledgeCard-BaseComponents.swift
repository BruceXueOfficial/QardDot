import SwiftUI
import UIKit

// MARK: - Question Mark Style

private enum ZDQuestionMarkStyleTokens {
    static let widthScale: CGFloat = 0.54
    static let heightScale: CGFloat = 0.78
    static let xOffsetScale: CGFloat = 0.012
    static let yOffsetScale: CGFloat = 0.05
}

struct ZDCardQuestionMarkLayer: View {
    @Environment(\.colorScheme) private var colorScheme

    let symbol: String
    let gradient: LinearGradient
    let canvasSize: CGSize
    let localAssetName: String?

    init(
        symbol: String,
        gradient: LinearGradient,
        canvasSize: CGSize,
        localAssetName: String? = nil
    ) {
        self.symbol = symbol
        self.gradient = gradient
        self.canvasSize = canvasSize
        self.localAssetName = localAssetName
    }

    var body: some View {
        let usesLocalAsset = localAssetName?.isEmpty == false
        let symbolSize = min(
            canvasSize.width * ZDQuestionMarkStyleTokens.widthScale,
            canvasSize.height * ZDQuestionMarkStyleTokens.heightScale
        )
        let baseOpacity = usesLocalAsset ? 1.0 : (colorScheme == .dark ? 0.90 : 0.80)
        let highlightOpacity = usesLocalAsset ? 0.0 : (colorScheme == .dark ? 0.22 : 0.18)
        let shadowOpacity = usesLocalAsset ? 0.18 : (colorScheme == .dark ? 0.30 : 0.14)

        return baseGlyph(size: symbolSize)
            .opacity(baseOpacity)
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: symbolSize * 0.08,
                x: 0,
                y: symbolSize * 0.045
            )
            .overlay {
                if highlightOpacity > 0 {
                    highlightGlyph(size: symbolSize, opacity: highlightOpacity)
                        .offset(x: -symbolSize * 0.01, y: -symbolSize * 0.01)
                        .blendMode(.screen)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(
                x: canvasSize.width * ZDQuestionMarkStyleTokens.xOffsetScale,
                y: canvasSize.height * ZDQuestionMarkStyleTokens.yOffsetScale
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func baseGlyph(size: CGFloat) -> some View {
        if let localAssetName, !localAssetName.isEmpty {
            Image(localAssetName)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbol)
                .foregroundStyle(gradient)
                .font(.system(size: size, weight: .bold, design: .rounded))
        }
    }

    @ViewBuilder
    private func highlightGlyph(size: CGFloat, opacity: Double) -> some View {
        if let localAssetName, !localAssetName.isEmpty {
            Image(localAssetName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(.white.opacity(opacity))
        } else {
            Image(systemName: symbol)
                .foregroundStyle(.white.opacity(opacity))
                .font(.system(size: size, weight: .bold, design: .rounded))
        }
    }

}

// MARK: - Tag Style

struct ZDCardTagChip: View {
    let text: String
    let textColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

struct ZDCardAdaptiveTagChipRow: View {
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
                    ZDCardTagChip(
                        text: tag,
                        textColor: chipTextColor,
                        backgroundColor: chipBackgroundColor
                    )
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

// MARK: - Punched Style

struct TitleCardPunchedShape: Shape {
    let cornerRadius: CGFloat
    let holeSize: CGFloat
    let holeInset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        let holeOriginX = rect.maxX - holeInset - holeSize
        let holeOriginY = rect.minY + holeInset
        let holeRect = CGRect(x: holeOriginX, y: holeOriginY, width: holeSize, height: holeSize)
        path.addEllipse(in: holeRect)
        return path
    }
}

struct KnowledgeCardPinHoleInnerShadow: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat = 13

    var body: some View {
        Circle()
            .stroke(Color.black.opacity(colorScheme == .dark ? 0.86 : 0.72), lineWidth: 1.65)
            .blur(radius: 0.26)
            .offset(y: 0.36)
            .mask(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.black.opacity(1.0), .black.opacity(0.38), .clear],
                            center: .center,
                            startRadius: size * 0.12,
                            endRadius: size * 0.58
                        )
                    )
            )
            .frame(width: size, height: size)
    }
}

struct ZDPunchedCardMetrics: Equatable {
    let cornerRadius: CGFloat
    let holeSize: CGFloat
    let holeInset: CGFloat

    init(cornerRadius: CGFloat, holeScale: CGFloat = 1.0) {
        self.cornerRadius = cornerRadius
        self.holeSize = max(5.4, cornerRadius * 0.6875 * holeScale)
        self.holeInset = max(4.4, cornerRadius * 0.5833 * holeScale)
    }
}

struct ZDCardPunchedSurfaceStyle {
    let metrics: ZDPunchedCardMetrics
    let borderGradient: LinearGradient
    var borderOpacity: Double = 0.58
    var lineWidth: CGFloat = 0.78
    var innerHighlightLightOpacity: Double = 0.2
    var innerHighlightDarkOpacity: Double = 0.08
}

private struct ZDPunchedGlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    let metrics: ZDPunchedCardMetrics
    let borderGradient: LinearGradient
    let borderOpacity: Double
    let lineWidth: CGFloat
    let innerHighlightLightOpacity: Double
    let innerHighlightDarkOpacity: Double

    private var punchedShape: TitleCardPunchedShape {
        TitleCardPunchedShape(
            cornerRadius: metrics.cornerRadius,
            holeSize: snapped(metrics.holeSize),
            holeInset: snapped(metrics.holeInset)
        )
    }

    private func snapped(_ value: CGFloat) -> CGFloat {
        let scale = max(displayScale, 1)
        return (value * scale).rounded() / scale
    }

    private var antiAliasCoverExpansion: CGFloat {
        1.0 / max(displayScale, 1)
    }

    @ViewBuilder
    private var transparentPinHoleCleanupOverlay: some View {
        GeometryReader { proxy in
            let holeSize = snapped(metrics.holeSize)
            let holeInset = snapped(metrics.holeInset)
            let centerX = proxy.size.width - holeInset - holeSize * 0.5
            let centerY = holeInset + holeSize * 0.5

            Circle()
                .fill(Color.black)
                .frame(
                    width: holeSize + antiAliasCoverExpansion,
                    height: holeSize + antiAliasCoverExpansion
                )
                .position(x: centerX, y: centerY)
                .blendMode(.destinationOut)
        }
        .allowsHitTesting(false)
    }

    func body(content: Content) -> some View {
        content
            .mask(punchedShape.fill(style: FillStyle(eoFill: true, antialiased: false)))
            .overlay(
                punchedShape
                    .stroke(borderGradient.opacity(borderOpacity), lineWidth: lineWidth)
            )
            .overlay(
                punchedShape
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(innerHighlightDarkOpacity)
                            : Color.white.opacity(innerHighlightLightOpacity),
                        lineWidth: 0.4
                    )
                    .padding(1)
            )
            .compositingGroup()
            .overlay {
                transparentPinHoleCleanupOverlay
            }
            .compositingGroup()
    }
}

private struct ZDPunchedGlassBackgroundModifier<Fill: ShapeStyle>: ViewModifier {
    let fill: Fill
    let metrics: ZDPunchedCardMetrics
    let borderGradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .background(
                TitleCardPunchedShape(
                    cornerRadius: metrics.cornerRadius,
                    holeSize: metrics.holeSize,
                    holeInset: metrics.holeInset
                )
                .fill(fill, style: FillStyle(eoFill: true))
            )
            .zdPunchedGlassSurface(
                metrics: metrics,
                borderGradient: borderGradient
            )
    }
}

struct ZDPunchedGlassCardSurface<Content: View>: View {
    let metrics: ZDPunchedCardMetrics
    let borderGradient: LinearGradient
    let borderOpacity: Double
    let lineWidth: CGFloat
    let innerHighlightLightOpacity: Double
    let innerHighlightDarkOpacity: Double
    let content: () -> Content

    init(
        metrics: ZDPunchedCardMetrics,
        borderGradient: LinearGradient,
        borderOpacity: Double = 0.58,
        lineWidth: CGFloat = 0.78,
        innerHighlightLightOpacity: Double = 0.2,
        innerHighlightDarkOpacity: Double = 0.08,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.metrics = metrics
        self.borderGradient = borderGradient
        self.borderOpacity = borderOpacity
        self.lineWidth = lineWidth
        self.innerHighlightLightOpacity = innerHighlightLightOpacity
        self.innerHighlightDarkOpacity = innerHighlightDarkOpacity
        self.content = content
    }

    var body: some View {
        content()
            .zdPunchedGlassSurface(
                metrics: metrics,
                borderGradient: borderGradient,
                borderOpacity: borderOpacity,
                lineWidth: lineWidth,
                innerHighlightLightOpacity: innerHighlightLightOpacity,
                innerHighlightDarkOpacity: innerHighlightDarkOpacity
            )
    }
}

extension View {
    func zdPunchedGlassSurface(
        metrics: ZDPunchedCardMetrics,
        borderGradient: LinearGradient,
        borderOpacity: Double = 0.58,
        lineWidth: CGFloat = 0.78,
        innerHighlightLightOpacity: Double = 0.2,
        innerHighlightDarkOpacity: Double = 0.08
    ) -> some View {
        modifier(
            ZDPunchedGlassSurfaceModifier(
                metrics: metrics,
                borderGradient: borderGradient,
                borderOpacity: borderOpacity,
                lineWidth: lineWidth,
                innerHighlightLightOpacity: innerHighlightLightOpacity,
                innerHighlightDarkOpacity: innerHighlightDarkOpacity
            )
        )
    }

    func zdPunchedGlassBackground<Fill: ShapeStyle>(
        _ fill: Fill,
        metrics: ZDPunchedCardMetrics,
        borderGradient: LinearGradient
    ) -> some View {
        modifier(
            ZDPunchedGlassBackgroundModifier(
                fill: fill,
                metrics: metrics,
                borderGradient: borderGradient
            )
        )
    }

    func zdCardPunchedGlassSurface(_ style: ZDCardPunchedSurfaceStyle) -> some View {
        zdPunchedGlassSurface(
            metrics: style.metrics,
            borderGradient: style.borderGradient,
            borderOpacity: style.borderOpacity,
            lineWidth: style.lineWidth,
            innerHighlightLightOpacity: style.innerHighlightLightOpacity,
            innerHighlightDarkOpacity: style.innerHighlightDarkOpacity
        )
    }

    func zdCardPunchedGlassBackground<Fill: ShapeStyle>(
        _ fill: Fill,
        style: ZDCardPunchedSurfaceStyle
    ) -> some View {
        zdPunchedGlassBackground(
            fill,
            metrics: style.metrics,
            borderGradient: style.borderGradient
        )
    }
}

#Preview("Punched Card Shape") {
    ZStack {
        Color.zdPageBase.ignoresSafeArea()

        TitleCardPunchedShape(cornerRadius: 24, holeSize: 16, holeInset: 14)
            .fill(LinearGradient.zdCardStandardTLBR, style: FillStyle(eoFill: true))
            .frame(width: 300, height: 170)
            .overlay {
                TitleCardPunchedShape(cornerRadius: 24, holeSize: 16, holeInset: 14)
                    .stroke(Color.zdAccentDeep.opacity(0.4), lineWidth: 0.9)
            }
    }
}

#Preview("Pin Hole Inner Shadow") {
    ZStack {
        Color.zdPageBase.ignoresSafeArea()

        Circle()
            .fill(Color.white)
            .frame(width: 56, height: 56)
            .overlay {
                KnowledgeCardPinHoleInnerShadow(size: 18)
            }
    }
}

private struct ZDPunchedGlassSurfacePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private let metrics = ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.02)
    private let border = LinearGradient(
        colors: [Color.blue.opacity(0.45), Color.cyan.opacity(0.45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let fill = LinearGradient(
        colors: [Color.blue.opacity(0.35), Color.cyan.opacity(0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Punched Surface")
                .font(.title3.weight(.bold))
            Text("打孔白晕预览")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 252, height: 150, alignment: .topLeading)
        .zdPunchedGlassBackground(fill, metrics: metrics, borderGradient: border)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
            radius: 6,
            x: 0,
            y: 4
        )
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("Punched Surface - Light") {
    ZDPunchedGlassSurfacePreviewCard()
        .preferredColorScheme(.light)
}

#Preview("Punched Surface - Dark") {
    ZDPunchedGlassSurfacePreviewCard()
        .preferredColorScheme(.dark)
}

private struct ZDQuestionMarkStylePreviewPanel: View {
    let localAssetName: String?

    init(localAssetName: String? = nil) {
        self.localAssetName = localAssetName
    }

    var body: some View {
        ZStack {
            Color.zdPageBase.ignoresSafeArea()

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient.zdCardStandardTLBR.opacity(0.28))
                .frame(width: 240, height: 120)
                .overlay {
                    ZDCardQuestionMarkLayer(
                        symbol: "questionmark",
                        gradient: LinearGradient(
                            colors: [
                                Color.zdAccentDeep.opacity(0.95),
                                Color.zdAccentSoft.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        canvasSize: CGSize(width: 240, height: 120),
                        localAssetName: localAssetName
                    )
                }
        }
    }
}

#Preview("Question Mark Style") {
    ZDQuestionMarkStylePreviewPanel()
}

#Preview("Question Mark SVG - Blue") {
    ZDQuestionMarkStylePreviewPanel(localAssetName: "Questionmark-Blue")
}

#Preview("Question Mark SVG - Green") {
    ZDQuestionMarkStylePreviewPanel(localAssetName: "Questionmark-Green")
}

#Preview("Question Mark SVG - Orange") {
    ZDQuestionMarkStylePreviewPanel(localAssetName: "Questionmark-Orange")
}

#Preview("Question Mark SVG - Pink") {
    ZDQuestionMarkStylePreviewPanel(localAssetName: "Questionmark-Pink")
}

private struct ZDTagStylePreviewPanel: View {
    var body: some View {
        ZStack {
            Color.zdPageBase.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ZDCardTagChip(text: "营养", textColor: .white, backgroundColor: Color.zdAccentDeep.opacity(0.85))
                    ZDCardTagChip(text: "健康", textColor: .white, backgroundColor: Color.zdAccentSoft.opacity(0.82))
                    ZDCardTagChip(text: "科普", textColor: .white, backgroundColor: Color.zdAccentDeep.opacity(0.72))
                }

                ZDCardAdaptiveTagChipRow(
                    tags: ["免疫", "维生素", "问答", "实用"],
                    chipTextColor: .white,
                    chipBackgroundColor: Color.zdAccentDeep.opacity(0.8),
                    overflowTextColor: .secondary,
                    trailingReservedWidth: 40
                )
                .frame(width: 220)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

#Preview("Tag Style") {
    ZDTagStylePreviewPanel()
}

#Preview("Card Base Components") {
    ZStack {
        Color.zdPageBase.ignoresSafeArea()

        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.8))
                    .frame(width: 220, height: 90)

                ZDCardQuestionMarkLayer(
                    symbol: "questionmark",
                    gradient: .init(
                        colors: [.blue.opacity(0.9), .cyan.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    canvasSize: CGSize(width: 220, height: 90),
                    localAssetName: "Questionmark-Blue"
                )
            }

            HStack(spacing: 6) {
                ZDCardTagChip(text: "营养", textColor: .white, backgroundColor: .blue.opacity(0.85))
                ZDCardTagChip(text: "健康", textColor: .white, backgroundColor: .cyan.opacity(0.85))
                Text("+2")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}
