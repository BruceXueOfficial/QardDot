import SwiftUI

// MARK: - Split Card Tokens

struct ZDFrostRecipe: Equatable {
    let glassOpacity: Double
    let materialOpacity: Double
    let blurRadius: CGFloat
}

struct ZDSplitCardLayout: Equatable {
    let cornerRadius: CGFloat
    let topRatio: CGFloat
    let contentPaddingTop: EdgeInsets
    let contentPaddingBottom: EdgeInsets
    let punchedMetrics: ZDPunchedCardMetrics
    let footerTopSpacerMin: CGFloat

    init(
        cornerRadius: CGFloat,
        topRatio: CGFloat,
        contentPaddingTop: EdgeInsets,
        contentPaddingBottom: EdgeInsets,
        punchedMetrics: ZDPunchedCardMetrics,
        footerTopSpacerMin: CGFloat = 10
    ) {
        self.cornerRadius = cornerRadius
        self.topRatio = topRatio
        self.contentPaddingTop = contentPaddingTop
        self.contentPaddingBottom = contentPaddingBottom
        self.punchedMetrics = punchedMetrics
        self.footerTopSpacerMin = footerTopSpacerMin
    }
}

struct ZDSplitCardPalette {
    let topFill: LinearGradient
    let bottomFill: LinearGradient
    let border: LinearGradient
    let questionGradient: LinearGradient
    let tagBackground: Color
    let tagText: Color
    let titleText: Color
    let bodyText: Color
    let metaText: Color
    let divider: Color
}

// MARK: - Split Glass Card

struct ZDSplitGlassCard<Header: View, BodyContent: View, Footer: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.zdListRenderProfile) private var renderProfile

    let layout: ZDSplitCardLayout
    let palette: ZDSplitCardPalette
    let topFrost: ZDFrostRecipe
    let bottomFrost: ZDFrostRecipe
    let questionSymbol: String
    let questionAssetName: String?
    let header: () -> Header
    let bodyContent: () -> BodyContent
    let footer: () -> Footer

    init(
        layout: ZDSplitCardLayout,
        palette: ZDSplitCardPalette,
        topFrost: ZDFrostRecipe,
        bottomFrost: ZDFrostRecipe,
        questionSymbol: String = "questionmark",
        questionAssetName: String? = nil,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.layout = layout
        self.palette = palette
        self.topFrost = topFrost
        self.bottomFrost = bottomFrost
        self.questionSymbol = questionSymbol
        self.questionAssetName = questionAssetName
        self.header = header
        self.bodyContent = body
        self.footer = footer
    }

    var body: some View {
        GeometryReader { proxy in
            let topHeight = max(0, proxy.size.height * layout.topRatio)
            let bottomHeight = max(0, proxy.size.height - topHeight)
            let dividerHeight = max(0.5, 1.0 / max(displayScale, 1))

            ZStack(alignment: .topLeading) {
                if renderProfile.showsQuestionIcon {
                    ZDCardQuestionMarkLayer(
                        symbol: questionSymbol,
                        gradient: palette.questionGradient,
                        canvasSize: proxy.size,
                        localAssetName: questionAssetName
                    )
                }

                VStack(spacing: 0) {
                    sectionLayer(
                        fill: palette.topFill,
                        recipe: topFrost,
                        glassStyle: .regular,
                        padding: layout.contentPaddingTop
                    ) {
                        header()
                    }
                        .frame(height: topHeight, alignment: .topLeading)

                    sectionLayer(
                        fill: palette.bottomFill,
                        recipe: bottomFrost,
                        glassStyle: .clear,
                        padding: layout.contentPaddingBottom
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            bodyContent()
                            Spacer(minLength: layout.footerTopSpacerMin)
                            footer()
                        }
                    }
                        .frame(height: bottomHeight, alignment: .topLeading)
                }

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: dividerHeight)
                    .offset(y: topHeight - dividerHeight / 2)
            }
        }
        .zdPunchedGlassSurface(
            metrics: layout.punchedMetrics,
            borderGradient: palette.border,
            innerHighlightLightOpacity: 0,
            innerHighlightDarkOpacity: 0
        )
    }

    @ViewBuilder
    private func sectionContent<SectionContent: View>(
        padding: EdgeInsets,
        @ViewBuilder content: @escaping () -> SectionContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(padding)
    }

    @ViewBuilder
    private func sectionLayer<SectionContent: View>(
        fill: LinearGradient,
        recipe: ZDFrostRecipe,
        glassStyle: ZDGlassLayerStyle,
        padding: EdgeInsets,
        @ViewBuilder content: @escaping () -> SectionContent
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(fill)
            glassLayer(recipe, style: glassStyle)
            sectionContent(padding: padding, content: content)
        }
    }

    private enum ZDGlassLayerStyle {
        case regular
        case clear
    }

    @ViewBuilder
    private func glassLayer(_ recipe: ZDFrostRecipe, style: ZDGlassLayerStyle) -> some View {
        let isRegular = style == .regular
        let fallbackMaterialOpacity = isRegular
            ? (colorScheme == .dark ? 0.36 : 0.3)
            : (colorScheme == .dark ? 0.20 : 0.12)
        let glassBaseOpacity = isRegular
            ? (colorScheme == .dark ? 0.05 : 0.06)
            : (colorScheme == .dark ? 0.04 : 0.02)
        let glassGain = isRegular ? 0.65 : 0.42
        let tintOpacity = recipe.materialOpacity * (isRegular ? 0.34 : 0.22)
        let blurRadius = recipe.blurRadius * (isRegular ? 0.95 : 0.75) * renderProfile.blurStrength
        let tunedFallbackOpacity = fallbackMaterialOpacity * renderProfile.materialStrength
        let tunedTintOpacity = tintOpacity * renderProfile.materialStrength

        switch renderProfile.glassQuality {
        case .off:
            lowCostGradientTone(isRegular: isRegular)
        case .simplified:
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(tunedFallbackOpacity)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(tunedTintOpacity * 0.42),
                            Color.white.opacity(tunedTintOpacity * 0.22),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .blur(radius: blurRadius)
                .clipped()
        case .full:
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(tunedFallbackOpacity)
                .overlay {
                    if #available(iOS 26.0, *) {
                        Color.white.opacity((glassBaseOpacity + recipe.glassOpacity * glassGain) * renderProfile.materialStrength)
                            .glassEffect(in: Rectangle())
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(tunedFallbackOpacity)
                    }
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(tunedTintOpacity),
                            Color.white.opacity(tunedTintOpacity * 0.45),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .blur(radius: blurRadius)
                .clipped()
        }
    }

    @ViewBuilder
    private func lowCostGradientTone(isRegular: Bool) -> some View {
        let whiteHighlight = colorScheme == .dark
            ? (isRegular ? 0.05 : 0.03)
            : (isRegular ? 0.12 : 0.08)
        let darkDepth = colorScheme == .dark
            ? (isRegular ? 0.12 : 0.08)
            : (isRegular ? 0.06 : 0.04)
        let accentTint = colorScheme == .dark
            ? (isRegular ? 0.05 : 0.035)
            : (isRegular ? 0.11 : 0.08)

        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(whiteHighlight),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(darkDepth)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.zdAccentSoft.opacity(accentTint),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

private enum ZDSplitGlassCardPreviewTokens {
    static let bannerSize = CGSize(width: 252, height: 248)

    static let layout = ZDSplitCardLayout(
        cornerRadius: 18,
        topRatio: 0.34,
        contentPaddingTop: EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 14),
        contentPaddingBottom: EdgeInsets(top: 12, leading: 12, bottom: 14, trailing: 14),
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.02)
    )

    static let topFrost = ZDFrostRecipe(
        glassOpacity: 0.01,
        materialOpacity: 0.01,
        blurRadius: 0.01
    )

    static let bottomFrost = ZDFrostRecipe(
        glassOpacity: 0.13,
        materialOpacity: 0.36,
        blurRadius: 3.8
    )

    static let palette = ZDSplitCardPalette(
        topFill: LinearGradient(
            colors: [Color.blue.opacity(0.05), Color.cyan.opacity(0.045)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        bottomFill: LinearGradient(
            colors: [Color.blue.opacity(0.25), Color.cyan.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        border: LinearGradient(
            colors: [Color.white.opacity(0.72), Color.blue.opacity(0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        questionGradient: LinearGradient(
            colors: [Color.white.opacity(0.94), Color.white.opacity(0.84), Color.cyan.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        tagBackground: Color.blue.opacity(0.72),
        tagText: .white,
        titleText: Color.black.opacity(0.90),
        bodyText: Color.black.opacity(0.55),
        metaText: Color.black.opacity(0.56),
        divider: Color.white.opacity(0.66)
    )
}

private struct ZDSplitGlassCardPreviewHost: View {
    private let palette = ZDSplitGlassCardPreviewTokens.palette

    var body: some View {
        ZDSplitGlassCard(
            layout: ZDSplitGlassCardPreviewTokens.layout,
            palette: palette,
            topFrost: ZDSplitGlassCardPreviewTokens.topFrost,
            bottomFrost: ZDSplitGlassCardPreviewTokens.bottomFrost,
            questionAssetName: "Questionmark-Blue"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ZDCardTagChip(
                        text: "Tag1",
                        textColor: palette.tagText,
                        backgroundColor: palette.tagBackground
                    )
                    ZDCardTagChip(
                        text: "Tag2",
                        textColor: palette.tagText,
                        backgroundColor: palette.tagBackground
                    )
                }

                Text("Title of the QardCard")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.titleText)
                    .lineLimit(2)
            }
        } body: {
            Text("Main Text Content of the QardCard\nMain Text Content of the QardCard\nMain Text Content of the QardCard")
                .font(.subheadline)
                .foregroundStyle(palette.bodyText)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        } footer: {
            HStack {
                Label("36", systemImage: "eye.fill")
                Spacer()
                Text("Feb 15, 2026")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.metaText)
        }
        .frame(
            width: ZDSplitGlassCardPreviewTokens.bannerSize.width,
            height: ZDSplitGlassCardPreviewTokens.bannerSize.height
        )
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("Split Glass - Light") {
    ZDSplitGlassCardPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Split Glass - Dark") {
    ZDSplitGlassCardPreviewHost()
        .preferredColorScheme(.dark)
}
