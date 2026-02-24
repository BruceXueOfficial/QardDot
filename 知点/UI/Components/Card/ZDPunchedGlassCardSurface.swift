import SwiftUI

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
//            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .overlay(
                        // 将 RoundedRectangle 替换为 punchedShape
                        punchedShape
                            .stroke(borderGradient.opacity(borderOpacity), lineWidth: lineWidth)
                    )
                    .overlay(
                        // 将 RoundedRectangle 替换为 punchedShape
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
