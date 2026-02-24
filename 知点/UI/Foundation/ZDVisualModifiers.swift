import SwiftUI

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
                Color.zdAccentDeep.opacity(colorScheme == .dark ? 0.5 : 0.3),
                Color.zdAccentSoft.opacity(colorScheme == .dark ? 0.5 : 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ZDSurfaceCardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

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
                    .overlay {
                        if #available(iOS 26.0, *) {
                            Color.white.opacity(materialOpacity)
                                .glassEffect(in: shape)
                        } else {
                            shape
                                .fill(.ultraThinMaterial)
                                .opacity(fallbackMaterialOpacity)
                        }
                    }
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

    private var surfaceGradient: LinearGradient {
        switch style {
        case .regular:
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color.zdSurface.opacity(0.92),
                        Color.zdSurfaceElevated.opacity(0.9),
                        Color.zdAccentDeep.opacity(0.14)
                    ]
                    : [
                        Color.white.opacity(0.88),
                        Color.zdAccentSoft.opacity(0.2),
                        Color.zdAccentMist.opacity(0.3)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .elevated:
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color.zdSurfaceElevated.opacity(0.95),
                        Color.zdSurface.opacity(0.92),
                        Color.zdAccentSoft.opacity(0.12)
                    ]
                    : [
                        Color.white.opacity(0.94),
                        Color.zdSurfaceElevated.opacity(0.92),
                        Color.zdAccentSoft.opacity(0.16)
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
                        Color.zdSurface.opacity(0.92),
                        Color.zdSurfaceElevated.opacity(0.88),
                        Color.red.opacity(0.2)
                    ]
                    : [
                        Color.white.opacity(0.88),
                        Color.zdAccentSoft.opacity(0.18),
                        Color.red.opacity(0.1)
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

    let solidHeight: CGFloat
    let fadeHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    topBlurFadeOverlay(safeTopInset: proxy.safeAreaInsets.top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private func topBlurFadeOverlay(safeTopInset: CGFloat) -> some View {
        let solidBandHeight = safeTopInset + solidHeight
        let totalHeight = solidBandHeight + fadeHeight
        let baseTintOpacity = colorScheme == .dark ? 0.07 : 0.09
        let fallbackMaterialOpacity = colorScheme == .dark ? 0.28 : 0.34
        let topHighlightOpacity = colorScheme == .dark ? 0.04 : 0.07
        let topMaskOpacity = colorScheme == .dark ? 0.74 : 0.68
        let midMaskOpacity = colorScheme == .dark ? 0.24 : 0.18

        ZStack {
            // Keep a subtle tint + blur so the top stays translucent instead of solid.
            Color.zdPageBase.opacity(baseTintOpacity)

            if #available(iOS 26.0, *) {
                Color.white.opacity(colorScheme == .dark ? 0.004 : 0.006)
                    .glassEffect(in: Rectangle())
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(fallbackMaterialOpacity)
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(topHighlightOpacity),
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
                    .opacity(topMaskOpacity)
                    .frame(height: solidBandHeight)

                LinearGradient(
                    colors: [
                        Color.black.opacity(topMaskOpacity),
                        Color.black.opacity(midMaskOpacity),
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
