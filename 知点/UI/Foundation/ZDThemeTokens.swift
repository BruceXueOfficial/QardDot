import SwiftUI
import UIKit

struct ZDTypographyScale {
    static let `default` = ZDTypographyScale()

    let pageTitle = Font.system(size: 30, weight: .heavy)
    let sectionTitle = Font.title3.weight(.semibold)
    let cardTitle = Font.headline.weight(.bold)
    let body = Font.body
    let caption = Font.caption
    let micro = Font.caption2
}

struct ZDSpacingScale {
    static let `default` = ZDSpacingScale()

    let pageHorizontal: CGFloat = 16
    let pageVertical: CGFloat = 12
    let section: CGFloat = 14
    let card: CGFloat = 12
    let compact: CGFloat = 8
}

struct ZDRadiusScale {
    static let `default` = ZDRadiusScale()

    let small: CGFloat = 10
    let medium: CGFloat = 14
    let large: CGFloat = 20
    let pill: CGFloat = 999
}

struct ZDShadowScale {
    static let `default` = ZDShadowScale()

    let surfaceRadius: CGFloat = 8
    let surfaceYOffset: CGFloat = 4
    let buttonRadius: CGFloat = 10
    let buttonYOffset: CGFloat = 4
}

struct ZDMotionScale {
    static let `default` = ZDMotionScale()

    let standard = Animation.spring(response: 0.3, dampingFraction: 0.84)
    let quick = Animation.easeInOut(duration: 0.2)
    let slow = Animation.spring(response: 0.4, dampingFraction: 0.82)
}

struct ZDThemeTokens {
    static let `default` = ZDThemeTokens()

    let background = Color.zdPageBase
    let surface = Color.zdSurface
    let surfaceElevated = Color.zdSurfaceElevated

    let accent = Color.zdAccentDeep
    let accentSoft = Color.zdAccentSoft
    let accentMist = Color.zdAccentMist

    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textSoft = Color.zdTextSoft

    let danger = Color.red

    var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.zdAccentDeep.opacity(0.5),
                Color.zdAccentSoft.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var interactiveFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.zdAccentDeep.opacity(0.9),
                Color.zdAccentSoft.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct ZDThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ZDThemeTokens.default
}

extension EnvironmentValues {
    var zdTheme: ZDThemeTokens {
        get { self[ZDThemeEnvironmentKey.self] }
        set { self[ZDThemeEnvironmentKey.self] = newValue }
    }
}

enum ZDMainPageLayout {
    static let contentTopInset: CGFloat = 16
}

extension Color {
    private static func zdDynamic(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    static let zdPaletteAqua = Color(red: 144.0 / 255.0, green: 1.0, blue: 1.0)
    static let zdPaletteBlue = Color(red: 0.0, green: 120.0 / 255.0, blue: 1.0)
    static let zdPaletteSky = Color(red: 0.0, green: 188.0 / 255.0, blue: 1.0)

    static let zdCanvas = zdDynamic(
        light: UIColor(red: 236.0 / 255.0, green: 250.0 / 255.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 8.0 / 255.0, green: 28.0 / 255.0, blue: 54.0 / 255.0, alpha: 1)
    )
    static let zdCanvasSecondary = zdDynamic(
        light: UIColor(red: 228.0 / 255.0, green: 246.0 / 255.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 10.0 / 255.0, green: 34.0 / 255.0, blue: 66.0 / 255.0, alpha: 1)
    )
    static let zdSurface = zdDynamic(
        light: UIColor(red: 243.0 / 255.0, green: 252.0 / 255.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 12.0 / 255.0, green: 40.0 / 255.0, blue: 78.0 / 255.0, alpha: 1)
    )
    static let zdSurfaceElevated = zdDynamic(
        light: UIColor(red: 250.0 / 255.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 16.0 / 255.0, green: 51.0 / 255.0, blue: 94.0 / 255.0, alpha: 1)
    )

    static let zdAccentDeep = Color.zdPaletteBlue
    static let zdAccentSoft = Color.zdPaletteSky
    static let zdAccentMist = Color.zdPaletteAqua

    static let zdPageBase = zdDynamic(
        light: UIColor.white,
        dark: UIColor.black
    )

    static let zdTextSoft = zdDynamic(
        light: UIColor(red: 0.0, green: 103.0 / 255.0, blue: 198.0 / 255.0, alpha: 1),
        dark: UIColor(red: 158.0 / 255.0, green: 224.0 / 255.0, blue: 1.0, alpha: 1)
    )

    static let zdPageLightBase = Color.white
    static let zdCardGradientStart = Color(red: 0.0, green: 187.0 / 255.0, blue: 1.0)
    static let zdCardGradientEnd = Color(red: 206.0 / 255.0, green: 242.0 / 255.0, blue: 1.0)
}

extension LinearGradient {
    static let zdCardStandardTLBR = LinearGradient(
        colors: [Color.zdCardGradientStart, Color.zdCardGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct ZDThemeTokensPreview: View {
    private let tokens = ZDThemeTokens.default

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZDSpacingScale.default.section) {
                Text("Theme Tokens")
                    .font(ZDTypographyScale.default.pageTitle)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                        .font(ZDTypographyScale.default.sectionTitle)
                    HStack(spacing: 10) {
                        tokenColorChip("Base", color: .zdPageBase)
                        tokenColorChip("Accent", color: tokens.accent)
                        tokenColorChip("Soft", color: tokens.accentSoft)
                        tokenColorChip("Mist", color: tokens.accentMist)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Typography")
                        .font(ZDTypographyScale.default.sectionTitle)
                    Text("Page Title")
                        .font(ZDTypographyScale.default.pageTitle)
                    Text("Section Title")
                        .font(ZDTypographyScale.default.sectionTitle)
                    Text("Body text sample")
                        .font(ZDTypographyScale.default.body)
                    Text("Caption sample")
                        .font(ZDTypographyScale.default.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gradient")
                        .font(ZDTypographyScale.default.sectionTitle)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tokens.interactiveFill)
                        .frame(height: 48)
                }
            }
            .padding(16)
        }
        .background(tokens.background.ignoresSafeArea())
    }

    private func tokenColorChip(_ title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                )
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Theme Tokens") {
    ZDThemeTokensPreview()
}
