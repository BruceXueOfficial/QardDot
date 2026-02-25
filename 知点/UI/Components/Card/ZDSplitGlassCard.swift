import SwiftUI

struct ZDSplitGlassCard<Header: View, BodyContent: View, Footer: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    let layout: ZDSplitCardLayout
    let palette: ZDSplitCardPalette
    let topFrost: ZDFrostRecipe
    let bottomFrost: ZDFrostRecipe
    let questionSymbol: String
    let header: () -> Header
    let bodyContent: () -> BodyContent
    let footer: () -> Footer

    init(
        layout: ZDSplitCardLayout,
        palette: ZDSplitCardPalette,
        topFrost: ZDFrostRecipe,
        bottomFrost: ZDFrostRecipe,
        questionSymbol: String = "questionmark",
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.layout = layout
        self.palette = palette
        self.topFrost = topFrost
        self.bottomFrost = bottomFrost
        self.questionSymbol = questionSymbol
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
                questionLayer(size: proxy.size)

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
                            Spacer(minLength: 10)
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
        let blurRadius = recipe.blurRadius * (isRegular ? 0.95 : 0.75)

        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(fallbackMaterialOpacity)
            .overlay {
                if #available(iOS 26.0, *) {
                    Color.white.opacity(glassBaseOpacity + recipe.glassOpacity * glassGain)
                        .glassEffect(in: Rectangle())
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(fallbackMaterialOpacity)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(tintOpacity),
                        Color.white.opacity(tintOpacity * 0.45),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .blur(radius: blurRadius)
            .clipped()
    }

    private func questionLayer(size: CGSize) -> some View {
        let symbolSize = min(size.width * 0.64, size.height * 0.92)
        let baseOpacity = colorScheme == .dark ? 0.94 : 0.96
        let echoOpacity = colorScheme == .dark ? 0.3 : 0.28
        let blurRadius = colorScheme == .dark ? 0.10 : 0.06

        return questionGlyph(size: symbolSize)
            .foregroundStyle(palette.questionGradient)
            .opacity(baseOpacity)
            .blur(radius: blurRadius)
            .overlay {
                questionGlyph(size: symbolSize)
                    .foregroundStyle(palette.questionGradient)
                    .opacity(echoOpacity)
                    .offset(x: 0.6, y: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: size.width * 0.025, y: size.height * 0.014)
            .allowsHitTesting(false)
    }

    private func questionGlyph(size: CGFloat) -> some View {
        Image(systemName: questionSymbol)
            .font(.system(size: size, weight: .black, design: .rounded))
    }
}

private struct ZDSplitGlassCardPreviewHost: View {
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ZDSplitCardPalette {
        CardThemeColor.blue.recommendationSplitPalette(in: colorScheme)
    }

    var body: some View {
        ZDSplitGlassCard(
            layout: ZDCardStyleTokens.recommendationSplitLayout,
            palette: palette,
            topFrost: ZDCardStyleTokens.recommendationTopFrost,
            bottomFrost: ZDCardStyleTokens.recommendationBottomFrost
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Tag1")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.tagBackground)
                        .foregroundStyle(palette.tagText)
                        .clipShape(Capsule())
                    Text("Tag2")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.tagBackground)
                        .foregroundStyle(palette.tagText)
                        .clipShape(Capsule())
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
            width: ZDCardStyleTokens.recommendationBannerSize.width,
            height: ZDCardStyleTokens.recommendationBannerSize.height
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
