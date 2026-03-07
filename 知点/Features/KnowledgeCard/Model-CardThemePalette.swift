import SwiftUI

struct ZDTagFolderTopPalette: Equatable {
    let deepBlock: Color
    let lightBand: Color
    let foldHighlight: Color
    let divider: Color
}

extension CardThemeColor {
    var tagFolderTopPalette: ZDTagFolderTopPalette {
        ZDTagFolderTopPalette(
            deepBlock: tagFolderTopDeepColor,
            lightBand: tagFolderTopLightColor,
            foldHighlight: tagFolderTopLightColor.opacity(0.42),
            divider: tagFolderTopDeepColor.opacity(0.32)
        )
    }

    var recommendationQuestionAssetName: String {
        switch self {
        case .blue:
            return "Questionmark-Blue"
        case .green:
            return "Questionmark-Green"
        case .orange:
            return "Questionmark-Orange"
        case .purple:
            return "Questionmark-Pink"
        }
    }

    func recommendationSplitPalette(
        in colorScheme: ColorScheme,
        renderMode: ZDListRenderMode = .visual
    ) -> ZDSplitCardPalette {
        let isDark = colorScheme == .dark
        let usePerformanceLightBase = !isDark && renderMode == .performance
        
        let topPrimaryBase = primaryColor
        let topSecondaryBase = secondaryColor
        let topPrimaryOpacity = 1.0
        let topSecondaryOpacity = 1.0

        let bottomPrimaryBase = usePerformanceLightBase ? performanceLightBottomPrimaryBase : fillPrimaryColor
        let bottomSecondaryBase = usePerformanceLightBase ? performanceLightBottomSecondaryBase : fillSecondaryColor
        let bottomPrimaryOpacity = 1.0
        let bottomSecondaryOpacity = 1.0

        let topFill = LinearGradient(
            colors: [
                topPrimaryBase.opacity(topPrimaryOpacity),
                topSecondaryBase.opacity(topSecondaryOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let bottomFill = LinearGradient(
            colors: [
                bottomPrimaryBase.opacity(bottomPrimaryOpacity),
                bottomSecondaryBase.opacity(bottomSecondaryOpacity)
            ],
            startPoint: usePerformanceLightBase ? .leading : .topLeading,
            endPoint: usePerformanceLightBase ? .trailing : .bottomTrailing
        )

        let questionGradient = LinearGradient(
            colors: [
                Color.white.opacity(isDark ? 0.3 : 0.4),
                Color.white.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return ZDSplitCardPalette(
            topFill: topFill,
            bottomFill: bottomFill,
            border: cardBorderGradient,
            questionGradient: questionGradient,
            tagBackground: primaryColor.opacity(0.9),
            tagText: .white,
            titleText: .white,
            bodyText: Color.white.opacity(0.85),
            metaText: isDark ? Color.white.opacity(0.82) : Color.black.opacity(0.56),
            divider: isDark ? Color.white.opacity(0.20) : Color.black.opacity(0.08)
        )
    }

    private var performanceLightBottomPrimaryBase: Color {
        switch self {
        case .blue:
            return Self.staticHexColor(0xF1FBFF)
        case .green:
            return Self.staticHexColor(0xF1FCF7)
        case .orange:
            return Self.staticHexColor(0xFFF7EB)
        case .purple:
            return Self.staticHexColor(0xF7F4FF)
        }
    }

    private var performanceLightBottomSecondaryBase: Color {
        switch self {
        case .blue:
            return Self.staticHexColor(0xBFE6F8)
        case .green:
            return Self.staticHexColor(0xC4ECD9)
        case .orange:
            return Self.staticHexColor(0xF9DEC0)
        case .purple:
            return Self.staticHexColor(0xDFD6FA)
        }
    }

    private static func staticHexColor(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

private struct ZDCardThemeBridgePreviewRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: CardThemeColor
    let renderMode: ZDListRenderMode

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme, renderMode: renderMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.displayName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.topFill)
                .overlay(
                    Image(theme.recommendationQuestionAssetName)
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .padding(.trailing, 6),
                    alignment: .trailing
                )
                .frame(height: 44)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.bottomFill)
                .frame(height: 44)
        }
    }
}

private struct ZDCardThemeBridgePreviewGrid: View {
    let themes: [CardThemeColor] = [.blue, .green, .orange, .purple]
    let renderMode: ZDListRenderMode

    var body: some View {
        VStack(spacing: 12) {
            ForEach(themes) { theme in
                ZDCardThemeBridgePreviewRow(theme: theme, renderMode: renderMode)
            }
        }
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("Theme Bridge - Light - 视效优先") {
    ZDCardThemeBridgePreviewGrid(renderMode: .visual)
        .preferredColorScheme(.light)
}

#Preview("Theme Bridge - Dark - 视效优先") {
    ZDCardThemeBridgePreviewGrid(renderMode: .visual)
        .preferredColorScheme(.dark)
}

#Preview("Theme Bridge - Light - 性能优先") {
    ZDCardThemeBridgePreviewGrid(renderMode: .performance)
        .preferredColorScheme(.light)
}

#Preview("Theme Bridge - Dark - 性能优先") {
    ZDCardThemeBridgePreviewGrid(renderMode: .performance)
        .preferredColorScheme(.dark)
}
