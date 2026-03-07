import SwiftUI
import UIKit

// MARK: - Tokens


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

// MARK: - Visual Modifiers


enum ZDSurfaceStyle {
    case regular
    case elevated
    case clear
    case error
}

private struct ZDBorderOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let isError: Bool
    let lineWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(borderGradient, lineWidth: lineWidth)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(innerHighlight, lineWidth: 0.4)
                    .padding(1)
            }
    }

    private var innerHighlight: Color {
        if isError {
            return colorScheme == .dark ? Color.zdAccentSoft.opacity(0.42) : Color.white.opacity(0.42)
        }
        return colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.42)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.zdAccentDeep.opacity(colorScheme == .dark ? 0.9 : 0.8),
                Color.zdAccentDeep.opacity(colorScheme == .dark ? 0.4 : 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ZDSurfaceCardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zdListRenderProfile) private var renderProfile

    let style: ZDSurfaceStyle
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(surfaceGradient)
                    .opacity(style == .clear ? 0 : 1)
                    .overlay(materialOverlay(in: shape))
            }
            .clipShape(shape)
            .overlay {
                ZDBorderOverlay(
                    cornerRadius: cornerRadius,
                    isError: style == .error,
                    lineWidth: lineWidth
                )
            }
    }

    @ViewBuilder
    private func materialOverlay(in shape: RoundedRectangle) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial).opacity(fallbackMaterialOpacity)
        }
    }

    private var materialOpacity: Double {
        switch style {
        case .regular:
            return colorScheme == .dark ? 0.02 : 0.05
        case .elevated:
            return colorScheme == .dark ? 0.026 : 0.062
        case .clear:
            return colorScheme == .dark ? 0.008 : 0.012
        case .error:
            return colorScheme == .dark ? 0.02 : 0.05
        }
    }

    private var fallbackMaterialOpacity: Double {
        switch style {
        case .regular:
            return colorScheme == .dark ? 0.34 : 0.55
        case .elevated:
            return colorScheme == .dark ? 0.4 : 0.62
        case .clear:
            return colorScheme == .dark ? 0.18 : 0.22
        case .error:
            return colorScheme == .dark ? 0.36 : 0.57
        }
    }

    private var performanceGlassOpacity: Double {
        switch style {
        case .regular:
            return colorScheme == .dark ? 0.012 : 0.02
        case .elevated:
            return colorScheme == .dark ? 0.014 : 0.022
        case .clear:
            return 0
        case .error:
            return colorScheme == .dark ? 0.012 : 0.02
        }
    }

    private var performanceFallbackMaterialOpacity: Double {
        switch style {
        case .regular:
            return colorScheme == .dark ? 0.2 : 0.26
        case .elevated:
            return colorScheme == .dark ? 0.24 : 0.3
        case .clear:
            return 0
        case .error:
            return colorScheme == .dark ? 0.22 : 0.28
        }
    }

    private var performanceSheenTopOpacity: Double {
        colorScheme == .dark ? 0.1 : 0.18
    }

    private var performanceSheenMidOpacity: Double {
        colorScheme == .dark ? 0.04 : 0.08
    }

    private var performanceCornerGlowOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.15
    }

    private var surfaceGradient: LinearGradient {
        switch style {
        case .regular, .elevated:
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(white: 0.16).opacity(0.4),
                        Color(white: 0.08).opacity(0.6)
                    ]
                    : [
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.1)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .clear:
            return LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
        case .error:
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(white: 0.16).opacity(0.4),
                        Color.red.opacity(0.2)
                    ]
                    : [
                        Color.white.opacity(0.5),
                        Color.red.opacity(0.15)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ZDPageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            Color.zdPageBase.ignoresSafeArea()
        }
    }
}

private struct ZDTopScrollBlurFadeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zdListRenderProfile) private var renderProfile

    let solidHeight: CGFloat
    let fadeHeight: CGFloat

    func body(content: Content) -> some View {
        Group {
            if renderProfile.topBlurFadeStyle == .none {
                content
            } else {
                content
                    .overlay(alignment: .top) {
                        GeometryReader { proxy in
                            topBlurFadeOverlay(safeTopInset: proxy.safeAreaInsets.top)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                        .allowsHitTesting(false)
                    }
            }
        }
    }

    @ViewBuilder
    private func topBlurFadeOverlay(safeTopInset: CGFloat) -> some View {
        let solidBandHeight = safeTopInset + solidHeight
        let totalHeight = solidBandHeight + fadeHeight
        let fallbackMaterialOpacity = (colorScheme == .dark ? 0.28 : 0.34) * renderProfile.materialStrength
        let fadeTokens: (baseTintOpacity: Double, topHighlightOpacity: Double, topMaskOpacity: Double, midMaskOpacity: Double) = {
            switch renderProfile.topBlurFadeStyle {
            case .none:
                return (0, 0, 0, 0)
            case .glass:
                return (
                    colorScheme == .dark ? 0.06 : 0.08,
                    colorScheme == .dark ? 0.04 : 0.07,
                    colorScheme == .dark ? 0.74 : 0.68,
                    colorScheme == .dark ? 0.24 : 0.18
                )
            case .gradient:
                // Stronger top cover for content occlusion under status bar.
                return (
                    colorScheme == .dark ? 0.32 : 0.48,
                    colorScheme == .dark ? 0.06 : 0.1,
                    colorScheme == .dark ? 0.96 : 0.92,
                    colorScheme == .dark ? 0.42 : 0.38
                )
            }
        }()

        ZStack {
            Color.zdPageBase.opacity(fadeTokens.baseTintOpacity)

            switch renderProfile.topBlurFadeStyle {
            case .none:
                Color.clear
            case .gradient:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.09),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            case .glass:
                if #available(iOS 26.0, *) {
                    Color.white.opacity((colorScheme == .dark ? 0.004 : 0.006) * renderProfile.materialStrength)
                        .glassEffect(in: Rectangle())
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(fallbackMaterialOpacity)
                }
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(fadeTokens.topHighlightOpacity),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: totalHeight)
        .mask(
            VStack(spacing: 0) {
                Color.black
                    .opacity(fadeTokens.topMaskOpacity)
                    .frame(height: solidBandHeight)

                LinearGradient(
                    colors: [
                        Color.black.opacity(fadeTokens.topMaskOpacity),
                        Color.black.opacity(fadeTokens.midMaskOpacity),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
            }
        )
        .ignoresSafeArea(edges: .top)
    }
}

extension View {
    func zdSurfaceCardStyle(
        _ style: ZDSurfaceStyle = .regular,
        cornerRadius: CGFloat = 14,
        lineWidth: CGFloat = 0.9
    ) -> some View {
        modifier(
            ZDSurfaceCardStyleModifier(
                style: style,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth
            )
        )
    }

    func zdInteractiveControlStyle(cornerRadius: CGFloat = 12) -> some View {
        zdSurfaceCardStyle(.elevated, cornerRadius: cornerRadius, lineWidth: 1.05)
    }

    func zdSectionContainerStyle(cornerRadius: CGFloat = 14) -> some View {
        zdSurfaceCardStyle(.regular, cornerRadius: cornerRadius, lineWidth: 1.0)
    }

    // Backward compatibility
    func zdHeavyBorder(
        cornerRadius: CGFloat = 14,
        isError: Bool = false,
        lineWidth: CGFloat = 0.5
    ) -> some View {
        overlay {
            ZDBorderOverlay(cornerRadius: cornerRadius, isError: isError, lineWidth: lineWidth)
        }
    }

    func zdPageBackground() -> some View {
        modifier(ZDPageBackgroundModifier())
    }

    func zdTopScrollBlurFade(
        solidHeight: CGFloat = 6,
        fadeHeight: CGFloat = 48
    ) -> some View {
        modifier(
            ZDTopScrollBlurFadeModifier(
                solidHeight: solidHeight,
                fadeHeight: fadeHeight
            )
        )
    }

    func zdGlassSurface(
        cornerRadius: CGFloat = 14,
        lineWidth: CGFloat = 0.5,
        isError: Bool = false,
        isClear: Bool = false
    ) -> some View {
        let style: ZDSurfaceStyle = isClear ? .clear : (isError ? .error : .regular)
        return zdSurfaceCardStyle(style, cornerRadius: cornerRadius, lineWidth: lineWidth)
    }
}

private struct ZDVisualModifiersPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Visual Modifiers")
                    .font(.system(size: 30, weight: .heavy))
                    .padding(.top, 16)

                styleCard(title: "Regular", style: .regular)
                styleCard(title: "Elevated", style: .elevated)
                styleCard(title: "Clear", style: .clear)
                styleCard(title: "Error", style: .error)

                ForEach(1..<8) { index in
                    Text("滚动内容示例 \(index)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .zdSurfaceCardStyle(.regular, cornerRadius: 12, lineWidth: 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .zdPageBackground()
        .zdTopScrollBlurFade()
    }

    private func styleCard(title: String, style: ZDSurfaceStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("这块区域演示 `zdSurfaceCardStyle(.\(String(describing: style)))`。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zdSurfaceCardStyle(style, cornerRadius: 14, lineWidth: 1.0)
    }
}

#Preview("Visual Modifiers Showcase") {
    ZDVisualModifiersPreview()
}
