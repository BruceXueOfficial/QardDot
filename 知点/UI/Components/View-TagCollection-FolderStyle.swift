import SwiftUI

// MARK: - Data Model

struct ZDTagCollectionFolderModel: Equatable {
    var tagName: String
    var cardCount: Int
    var textModuleCount: Int
    var imageModuleCount: Int
    var codeModuleCount: Int
    var linkModuleCount: Int
    var formulaModuleCount: Int
    var addedDateText: String
    var viewCount: Int

    static let demo = ZDTagCollectionFolderModel(
        tagName: "标签名称",
        cardCount: 12,
        textModuleCount: 30,
        imageModuleCount: 8,
        codeModuleCount: 20,
        linkModuleCount: 5,
        formulaModuleCount: 6,
        addedDateText: "Feb 14 2026",
        viewCount: 20
    )
}

// MARK: - Tokens

private enum ZDTagCollectionFolderStyleTokens {
    static let surfaceSize = KnowledgeCardMViewTokens.surfaceSize
    static let foldWidthRatio: CGFloat = 0.775
    static let topRightLayerDrop: CGFloat = 2
    static let titleTopPadding: CGFloat = 5
    static let titleLeadingPadding: CGFloat = 14
    static let titleDividerHeight: CGFloat = 0.7
    static let titleDividerRightInset: CGFloat = 10

    static let splitLayout: ZDSplitCardLayout = {
        let base = KnowledgeCardMViewTokens.splitLayout
        return ZDSplitCardLayout(
            cornerRadius: base.cornerRadius,
            topRatio: 0.22,
            contentPaddingTop: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            contentPaddingBottom: EdgeInsets(top: 10, leading: 0, bottom: 14, trailing: 0),
            punchedMetrics: ZDPunchedCardMetrics(cornerRadius: base.cornerRadius, holeScale: 1.08),
            footerTopSpacerMin: base.footerTopSpacerMin
        )
    }()

    // Reuse L/M card glass recipes so visual/performance behavior remains identical.
    static let topFrost = KnowledgeCardLViewTokens.topFrost
    static let bottomFrost = KnowledgeCardMViewTokens.bottomFrost
}

private enum ZDTagCollectionFolderShadowTuning {
    static let baseLightOpacity: Double = 0.09
    static let baseDarkOpacity: Double = 0.24
    static let baseLightRadius: CGFloat = 5
    static let baseDarkRadius: CGFloat = 7
    static let baseLightY: CGFloat = 4
    static let baseDarkY: CGFloat = 5
}

// MARK: - Main Card

struct ZDTagCollectionFolderStyleCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let model: ZDTagCollectionFolderModel
    var theme: CardThemeColor = .defaultTheme
    private let forcedRenderMode: ZDListRenderMode = .performance

    private var forcedRenderProfile: ZDListRenderProfile {
        forcedRenderMode.profile(for: .knowledgeSquare)
    }

    private var palette: ZDSplitCardPalette {
        theme.recommendationSplitPalette(in: colorScheme, renderMode: forcedRenderMode)
    }

    private var foldTopTextColor: Color {
        Color.white.opacity(colorScheme == .dark ? 0.94 : 0.97)
    }

    private var topRightLayerGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.tagFolderTopLightColor.opacity(colorScheme == .dark ? 0.98 : 0.96),
                theme.tagFolderTopLightColor.opacity(colorScheme == .dark ? 0.90 : 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var styledPalette: ZDSplitCardPalette {
        ZDSplitCardPalette(
            topFill: LinearGradient(
                colors: [.clear, .clear],
                startPoint: .top,
                endPoint: .bottom
            ),
            bottomFill: LinearGradient(
                colors: [
                    theme.tagFolderTopDeepColor,
                    theme.tagFolderTopLightColor
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            border: palette.border,
            questionGradient: palette.questionGradient,
            tagBackground: .white.opacity(0.3),
            tagText: .white,
            titleText: .white,
            bodyText: .white,
            metaText: .white.opacity(colorScheme == .dark ? 0.90 : 0.94),
            divider: .clear
        )
    }

    private var rightTopLayerCornerRadius: CGFloat {
        ZDTagCollectionFolderStyleTokens.splitLayout.cornerRadius
    }

    var body: some View {
        decoratedCardSurface
            .frame(width: ZDTagCollectionFolderStyleTokens.surfaceSize.width, alignment: .leading)
    }

    @ViewBuilder
    private var decoratedCardSurface: some View {
        ZDSplitGlassCard(
            layout: ZDTagCollectionFolderStyleTokens.splitLayout,
            palette: styledPalette,
            topFrost: ZDTagCollectionFolderStyleTokens.topFrost,
            bottomFrost: ZDTagCollectionFolderStyleTokens.bottomFrost,
            showsSurfaceBorder: false,
            questionAssetName: theme.recommendationQuestionAssetName
        ) {
            GeometryReader { proxy in
                let foldWidth = proxy.size.width * ZDTagCollectionFolderStyleTokens.foldWidthRatio
                let rightDrop = ZDTagCollectionFolderStyleTokens.topRightLayerDrop
                let foldDividerWidth = min(max(104, foldWidth * 0.68), max(104, foldWidth - 26))
                let rightLayerHeight = max(0, proxy.size.height - rightDrop)

                ZStack(alignment: .topLeading) {
                    ZDTagCollectionFolderTopRoundedShape(cornerRadius: rightTopLayerCornerRadius)
                        .fill(topRightLayerGradient)
                        .frame(width: proxy.size.width, height: rightLayerHeight)
                        .offset(y: rightDrop)
                        .overlay {
                            ZDTagCollectionFolderTopRoundedShape(cornerRadius: rightTopLayerCornerRadius)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.30), lineWidth: 0.7)
                                .frame(width: proxy.size.width, height: rightLayerHeight)
                                .offset(y: rightDrop)
                        }

                    ZDTagCollectionFolderFoldShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.tagFolderTopDeepColor,
                                    theme.tagFolderTopDeepColor.opacity(colorScheme == .dark ? 0.98 : 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: foldWidth, height: proxy.size.height, alignment: .leading)
                        .clipped()

                    Text(model.tagName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(foldTopTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.leading, 14)
                        .padding(.top, 10)

                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.54 : 0.62))
                        .frame(width: foldDividerWidth, height: 1.2)
                        .offset(
                            x: 14,
                            y: max(0, proxy.size.height - 0.9)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } body: {
            VStack(alignment: .leading, spacing: 0) {
                Text("标签包含 \(model.cardCount) 张卡片")
                    .padding(.horizontal, 14)

                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(colorScheme == .dark ? 0.90 : 0.96))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } footer: {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                    Text("\(model.viewCount)")
                        .monospacedDigit()
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                Text("添加时间 \(model.addedDateText)")
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .font(.caption.weight(.semibold))
            .foregroundStyle(styledPalette.metaText)
        }
        .frame(
            width: ZDTagCollectionFolderStyleTokens.surfaceSize.width,
            height: ZDTagCollectionFolderStyleTokens.surfaceSize.height
        )
        .environment(\.zdListRenderMode, forcedRenderMode)
        .shadow(
            color: Color.black.opacity(
                (colorScheme == .dark
                    ? ZDTagCollectionFolderShadowTuning.baseDarkOpacity
                    : ZDTagCollectionFolderShadowTuning.baseLightOpacity
                ) * forcedRenderProfile.primaryShadowStrength
            ),
            radius: (colorScheme == .dark
                ? ZDTagCollectionFolderShadowTuning.baseDarkRadius
                : ZDTagCollectionFolderShadowTuning.baseLightRadius
            ) * forcedRenderProfile.primaryShadowStrength,
            x: 0,
            y: (colorScheme == .dark
                ? ZDTagCollectionFolderShadowTuning.baseDarkY
                : ZDTagCollectionFolderShadowTuning.baseLightY
            ) * forcedRenderProfile.primaryShadowStrength
        )
    }
}

// MARK: - Fold Shape (SVG-based)

private struct ZDTagCollectionFolderFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let corner = min(rect.height * 0.32, 14)
        let topCutStartX = max(corner + 24, rect.width * 0.72)
        let bottomCutEndX = max(topCutStartX + 20, rect.width * 0.93)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: corner))
        path.addQuadCurve(
            to: CGPoint(x: corner, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.addLine(to: CGPoint(x: topCutStartX, y: 0))
        path.addLine(to: CGPoint(x: bottomCutEndX, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct ZDTagCollectionFolderTopRoundedShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.height * 0.5, rect.width * 0.5)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

private struct ZDTagCollectionFolderPreviewGallery: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(CardThemeColor.allCases) { theme in
                    ZDTagCollectionFolderStyleCard(
                        model: .demo,
                        theme: theme
                    )
                }
            }
            .padding()
        }
        .background(Color.zdPageBase)
        .environment(\.zdListRenderMode, .performance)
    }
}

#Preview("Tag Folder - 默认蓝色（性能模式）") {
    ZDTagCollectionFolderStyleCard(
        model: .demo,
        theme: .blue
    )
    .padding()
    .background(Color.zdPageBase)
}

#Preview("Tag Folder - 四主题（性能模式）") {
    ZDTagCollectionFolderPreviewGallery()
}
