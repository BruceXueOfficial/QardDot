import SwiftUI

extension CardThemeColor {
    func recommendationSplitPalette(in colorScheme: ColorScheme) -> ZDSplitCardPalette {
        let isDark = colorScheme == .dark
        let isBlueLight = !isDark && self == .blue

        let topFill = LinearGradient(
            colors: [
                primaryColor.opacity(isDark ? 0.74 : (isBlueLight ? 0.56 : 0.4)),
                secondaryColor.opacity(isDark ? 0.70 : (isBlueLight ? 0.46 : 0.3))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let bottomFill = LinearGradient(
            colors: [
                fillPrimaryColor.opacity(isDark ? 0.60 : (isBlueLight ? 0.54 : 0.44)),
                fillSecondaryColor.opacity(isDark ? 0.68 : (isBlueLight ? 0.42 : 0.32))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let questionGradient = LinearGradient(
            colors: [
                primaryColor.opacity(isDark ? 0.98 : 0.96),
                secondaryColor.opacity(isDark ? 0.96 : 0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return ZDSplitCardPalette(
            topFill: topFill,
            bottomFill: bottomFill,
            border: cardBorderGradient,
            questionGradient: questionGradient,
            tagBackground: primaryColor.opacity(isDark ? 0.64 : 0.78),
            tagText: .white,
            titleText: isDark ? Color.white.opacity(0.94) : Color.black.opacity(0.90),
            bodyText: isDark ? Color.white.opacity(0.84) : Color.black.opacity(0.55),
            metaText: isDark ? Color.white.opacity(0.82) : Color.black.opacity(0.56),
            divider: isDark ? Color.white.opacity(0.20) : Color.white.opacity(0.66)
        )
    }
}

private struct ZDCardThemeBridgePreviewRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: CardThemeColor

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.displayName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.topFill)
                .overlay(
                    Image(systemName: "questionmark")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(palette.questionGradient)
                        .opacity(0.8)
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

    var body: some View {
        VStack(spacing: 12) {
            ForEach(themes) { theme in
                ZDCardThemeBridgePreviewRow(theme: theme)
            }
        }
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("Theme Bridge - Light") {
    ZDCardThemeBridgePreviewGrid()
        .preferredColorScheme(.light)
}

#Preview("Theme Bridge - Dark") {
    ZDCardThemeBridgePreviewGrid()
        .preferredColorScheme(.dark)
}
