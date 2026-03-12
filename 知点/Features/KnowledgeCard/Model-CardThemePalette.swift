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
        case .red:
            return "Questionmark-Pink"
        case .cyan:
            return "Questionmark-Blue"
        case .yellow:
            return "Questionmark-Orange"
        case .pink:
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

        let bottomPrimaryBase = isDark ? fillPrimaryColor : lightThemeBottomPrimaryBase
        let bottomSecondaryBase = isDark ? fillSecondaryColor : lightThemeBottomSecondaryBase
        let bottomPrimaryOpacity = isDark ? 1.0 : 0.90
        let bottomSecondaryOpacity = isDark ? 1.0 : 0.76

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

    func pickerSolidGradient(in colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                secondaryColor.opacity(colorScheme == .dark ? 0.90 : 0.98),
                primaryColor.opacity(colorScheme == .dark ? 0.98 : 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func pickerStrokeColor(in colorScheme: ColorScheme, isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.28)
                : Color.white.opacity(0.78)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.12)
            : primaryColor.opacity(0.24)
    }

    private var lightThemeBottomPrimaryBase: Color {
        let (primaryHex, _) = lightThemeBaseHexPair
        return Self.mixWithWhite(primaryHex, whiteRatio: 0.92)
    }

    private var lightThemeBottomSecondaryBase: Color {
        let (_, secondaryHex) = lightThemeBaseHexPair
        return Self.mixWithWhite(secondaryHex, whiteRatio: 0.70)
    }

    private var lightThemeBaseHexPair: (primary: Int, secondary: Int) {
        switch self {
        case .blue:
            return (0x0052D4, 0x0088FF)
        case .green:
            return (0x008A27, 0x00C23A)
        case .orange:
            return (0xE65C00, 0xFF9500)
        case .purple:
            return (0x6100E6, 0xA233FF)
        case .red:
            return (0xD00000, 0xFF3B30)
        case .cyan:
            return (0x008A99, 0x00C7BE)
        case .yellow:
            return (0xD49A00, 0xFFCC00)
        case .pink:
            return (0xFF2D55, 0xFF6B8B)
        }
    }

    private static func mixWithWhite(_ hex: Int, whiteRatio: Double) -> Color {
        let clampedRatio = min(max(whiteRatio, 0), 1)
        let sourceRatio = 1 - clampedRatio

        let red = Double((hex >> 16) & 0xFF)
        let green = Double((hex >> 8) & 0xFF)
        let blue = Double(hex & 0xFF)

        return Color(
            red: ((red * sourceRatio) + 255 * clampedRatio) / 255.0,
            green: ((green * sourceRatio) + 255 * clampedRatio) / 255.0,
            blue: ((blue * sourceRatio) + 255 * clampedRatio) / 255.0
        )
    }
}

enum ZDThemePickerLayout {
    static let compactSheetHeight: CGFloat = 382
    static let cardPreviewWidth: CGFloat = 170
    static let twoColumnGridSpacing: CGFloat = 12
    static let swatchSize: CGFloat = 48

    static func tagFolderPreviewWidth(for availableWidth: CGFloat) -> CGFloat {
        let contentWidth = max(0, availableWidth - ZDSpacingScale.default.pageHorizontal * 2)
        let cellWidth = (contentWidth - twoColumnGridSpacing) / 2
        return max(0, floor(cellWidth))
    }
}

struct ZDCardThemeSurfaceSwatch: View {
    let theme: CardThemeColor
    var isSelected: Bool = false

    var body: some View {
        ZDThemeColorCircleSwatch(theme: theme, isSelected: isSelected)
    }
}

struct ZDTagFolderThemeSurfaceSwatch: View {
    let theme: CardThemeColor
    var isSelected: Bool = false

    var body: some View {
        ZDThemeColorCircleSwatch(theme: theme, isSelected: isSelected)
    }
}

private struct ZDThemeColorCircleSwatch: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: CardThemeColor
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(theme.pickerSolidGradient(in: colorScheme))
            .overlay {
                Circle()
                    .strokeBorder(
                        theme.pickerStrokeColor(in: colorScheme, isSelected: isSelected),
                        lineWidth: isSelected ? 3 : 1.2
                    )
            }
            .frame(width: ZDThemePickerLayout.swatchSize, height: ZDThemePickerLayout.swatchSize)
            .shadow(color: theme.primaryColor.opacity(0.35), radius: 6, x: 0, y: 3)
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18), radius: 1.2, x: 0, y: -0.5)
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
