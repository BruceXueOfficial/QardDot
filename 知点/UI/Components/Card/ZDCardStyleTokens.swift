import SwiftUI

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

enum ZDCardStyleTokens {
    static let recommendationBannerSize = CGSize(width: 252, height: 248)

    static let recommendationSplitLayout = ZDSplitCardLayout(
        cornerRadius: 18,
        topRatio: 0.34,
        contentPaddingTop: EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 14),
        contentPaddingBottom: EdgeInsets(top: 12, leading: 12, bottom: 14, trailing: 14),
        punchedMetrics: ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.02)
    )

    static let recommendationTopFrost = ZDFrostRecipe(
        glassOpacity: 0.025,
        materialOpacity: 0.07,
        blurRadius: 0.55
    )

    static let recommendationBottomFrost = ZDFrostRecipe(
        glassOpacity: 0.13,
        materialOpacity: 0.36,
        blurRadius: 3.8
    )
}

private struct ZDCardStyleTokensPreviewPanel: View {
    private let layout = ZDCardStyleTokens.recommendationSplitLayout
    private let top = ZDCardStyleTokens.recommendationTopFrost
    private let bottom = ZDCardStyleTokens.recommendationBottomFrost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ZDCardStyleTokens")
                .font(.headline.weight(.bold))
            Group {
                Text("cornerRadius: \(layout.cornerRadius, specifier: "%.1f")")
                Text("topRatio: \(layout.topRatio, specifier: "%.2f")")
                Text("holeSize: \(layout.punchedMetrics.holeSize, specifier: "%.2f")")
                Text("holeInset: \(layout.punchedMetrics.holeInset, specifier: "%.2f")")
                Text("topFrost(g/m/b): \(top.glassOpacity, specifier: "%.2f") / \(top.materialOpacity, specifier: "%.2f") / \(top.blurRadius, specifier: "%.2f")")
                Text("bottomFrost(g/m/b): \(bottom.glassOpacity, specifier: "%.2f") / \(bottom.materialOpacity, specifier: "%.2f") / \(bottom.blurRadius, specifier: "%.2f")")
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .padding()
        .background(Color.zdPageBase)
    }
}

#Preview("Card Tokens") {
    ZDCardStyleTokensPreviewPanel()
}
