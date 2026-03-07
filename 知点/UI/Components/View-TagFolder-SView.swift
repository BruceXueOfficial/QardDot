import SwiftUI

// MARK: - Tokens

private enum ZDTagCollectionFolderSViewTokens {
    static let surfaceHeight = KnowledgeCardSViewTokens.surfaceHeight
    static let foldWidthRatio: CGFloat = 0.775
    static let titleTopPadding: CGFloat = 7
    static let titleLeadingPadding: CGFloat = 14
    static let titleFontSize: CGFloat = 16.5
    static let titleDividerHeight: CGFloat = 0.7
    static let titleDividerRightInset: CGFloat = 22
    static let innerCardInset: CGFloat = 2

    static let splitLayout: ZDSplitCardLayout = {
        let base = KnowledgeCardSViewTokens.splitLayout
        return ZDSplitCardLayout(
            cornerRadius: base.cornerRadius,
            topRatio: 0.28,
            contentPaddingTop: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            contentPaddingBottom: EdgeInsets(top: 8, leading: 0, bottom: 10, trailing: 0),
            punchedMetrics: ZDPunchedCardMetrics(
                cornerRadius: base.cornerRadius,
                holeScale: 0.98,
                holeOffsetX: -innerCardInset,
                holeOffsetY: innerCardInset
            ),
            footerTopSpacerMin: base.footerTopSpacerMin
        )
    }()

    // Reuse SView card glass recipes
    static let topFrost = KnowledgeCardSViewTokens.topFrost
    static let bottomFrost = KnowledgeCardSViewTokens.bottomFrost
}

private enum ZDTagCollectionFolderSViewShadowTuning {
    static let baseLightOpacity: Double = 0.08
    static let baseDarkOpacity: Double = 0.2
    static let baseLightRadius: CGFloat = 4
    static let baseDarkRadius: CGFloat = 6
    static let baseLightY: CGFloat = 3
    static let baseDarkY: CGFloat = 4
}

// MARK: - Main SView Card

struct ZDTagCollectionFolderSView: View {
    @Environment(\.colorScheme) private var colorScheme

    let model: ZDTagCollectionFolderModel
    var theme: CardThemeColor = .defaultTheme
    private let forcedRenderMode: ZDListRenderMode = .performance

    private var forcedRenderProfile: ZDListRenderProfile {
        forcedRenderMode.profile(for: .warehouse)
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
                colors: [.clear, .clear],
                startPoint: .top,
                endPoint: .bottom
            ),
            border: palette.border,
            questionGradient: palette.questionGradient,
            tagBackground: theme.primaryColor.opacity(0.9),
            tagText: .white,
            titleText: .white,
            bodyText: .white,
            metaText: .white.opacity(colorScheme == .dark ? 0.90 : 0.94),
            divider: .clear
        )
    }

    private var rightTopLayerCornerRadius: CGFloat {
        ZDTagCollectionFolderSViewTokens.splitLayout.cornerRadius
    }

    var body: some View {
        decoratedCardSurface
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var decoratedCardSurface: some View {
        ZDSplitGlassCard(
            layout: ZDTagCollectionFolderSViewTokens.splitLayout,
            palette: styledPalette,
            topFrost: ZDTagCollectionFolderSViewTokens.topFrost,
            bottomFrost: ZDTagCollectionFolderSViewTokens.bottomFrost,
            showsSurfaceBorder: false,
            questionAssetName: theme.recommendationQuestionAssetName
        ) {
            GeometryReader { proxy in
                let foldWidth = proxy.size.width * ZDTagCollectionFolderSViewTokens.foldWidthRatio
                let foldCorner = min(proxy.size.height * 0.32, 14)
                let foldCutStartX = max(foldCorner + 24, foldWidth * 0.72)
                let foldJoinX = max(foldCutStartX + 20, foldWidth * 0.93)
                let foldDividerWidth = max(
                    92,
                    foldJoinX - ZDTagCollectionFolderSViewTokens.titleLeadingPadding - ZDTagCollectionFolderSViewTokens.titleDividerRightInset
                )

                let folderMainShape = ZDTagCollectionFolderCombinedShape(
                    topCornerRadius: rightTopLayerCornerRadius,
                    topBandHeight: proxy.size.height,
                    cutStartX: foldCutStartX,
                    joinX: foldJoinX,
                    joinRadius: min(proxy.size.height * 0.28, 18)
                )

                let innerInset = ZDTagCollectionFolderSViewTokens.innerCardInset
                let topLayerWidth = proxy.size.width - innerInset
                // Add an additional 20 points of height to ensure the rear card's bottom boundary 
                // reaches past the right corner rounding, hiding any gaps completely.
                let topLayerHeight = proxy.size.height + 20
                let topLayerOffsetX: CGFloat = 0
                let topLayerOffsetY = innerInset

                ZStack(alignment: .topLeading) {
                    ZDTagCollectionFolderTopRoundedShape(cornerRadius: rightTopLayerCornerRadius)
                        .fill(topRightLayerGradient)
                        .frame(width: topLayerWidth, height: topLayerHeight)
                        .offset(x: topLayerOffsetX, y: topLayerOffsetY)
                        .overlay {
                            ZDTagCollectionFolderTopRoundedShape(cornerRadius: rightTopLayerCornerRadius)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.30), lineWidth: 0.7)
                                .frame(width: topLayerWidth, height: topLayerHeight)
                                .offset(x: topLayerOffsetX, y: topLayerOffsetY)
                        }
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.30),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: topLayerWidth, height: topLayerHeight)
                            .offset(x: topLayerOffsetX, y: topLayerOffsetY)
                            .mask(
                                ZDTagCollectionFolderTopRoundedShape(cornerRadius: rightTopLayerCornerRadius)
                                    .frame(width: topLayerWidth, height: topLayerHeight)
                                    .offset(x: topLayerOffsetX, y: topLayerOffsetY)
                            )
                        }

                    folderMainShape
                        // 1. Modifying Gradient of the main folder cover: 
                        // It uses the base color with varied opacities for a vibrant, layered gradient effect.
                        // (You can modify the opacity thresholds here for fine-tuning)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.tagFolderTopDeepColor.opacity(colorScheme == .dark ? 0.90 : 0.82),
                                    theme.tagFolderTopDeepColor,
                                    theme.tagFolderTopDeepColor.opacity(colorScheme == .dark ? 0.96 : 0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        // 4. Added external drop shadow for layered depth feel:
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 6, x: -1, y: 3)
                        .overlay {
                            // 3. New gradient border for folder front cover:
                            folderMainShape
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.5 : 0.8),
                                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                                            Color.white.opacity(colorScheme == .dark ? 0.3 : 0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                        }
                        .frame(
                            width: proxy.size.width,
                            height: ZDTagCollectionFolderSViewTokens.surfaceHeight,
                            alignment: .topLeading
                        )

                    HStack(spacing: 4) {
                        Text(model.tagName)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: ZDTagCollectionFolderSViewTokens.titleFontSize * 0.75, weight: .bold))
                    }
                    .font(.system(size: ZDTagCollectionFolderSViewTokens.titleFontSize, weight: .bold))
                    .foregroundStyle(foldTopTextColor)
                    .padding(.leading, ZDTagCollectionFolderSViewTokens.titleLeadingPadding)
                    .padding(.top, ZDTagCollectionFolderSViewTokens.titleTopPadding)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.50 : 0.60),
                                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.30)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: foldDividerWidth, height: ZDTagCollectionFolderSViewTokens.titleDividerHeight)
                        .offset(
                            x: ZDTagCollectionFolderSViewTokens.titleLeadingPadding,
                            y: max(0, proxy.size.height - ZDTagCollectionFolderSViewTokens.titleDividerHeight / 2)
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
        .frame(height: ZDTagCollectionFolderSViewTokens.surfaceHeight)
        .environment(\.zdListRenderMode, forcedRenderMode)
        .shadow(
            color: Color.black.opacity(
                (colorScheme == .dark
                    ? ZDTagCollectionFolderSViewShadowTuning.baseDarkOpacity
                    : ZDTagCollectionFolderSViewShadowTuning.baseLightOpacity
                ) * forcedRenderProfile.primaryShadowStrength
            ),
            radius: (colorScheme == .dark
                ? ZDTagCollectionFolderSViewShadowTuning.baseDarkRadius
                : ZDTagCollectionFolderSViewShadowTuning.baseLightRadius
            ) * forcedRenderProfile.primaryShadowStrength,
            x: 0,
            y: (colorScheme == .dark
                ? ZDTagCollectionFolderSViewShadowTuning.baseDarkY
                : ZDTagCollectionFolderSViewShadowTuning.baseLightY
            ) * forcedRenderProfile.primaryShadowStrength
        )
    }
}

// 修改后的圆润 Shape，利用 addArc 完美处理转角相切
private struct ZDTagCollectionFolderCombinedShape: Shape {
    let topCornerRadius: CGFloat
    let topBandHeight: CGFloat
    let cutStartX: CGFloat
    let joinX: CGFloat
    let joinRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topR = min(topCornerRadius, rect.width * 0.5, rect.height * 0.5)
        let bottomR = topR // Ensure matching bottom corner radius
        
        let bandY = min(max(0, topBandHeight), rect.height)
        let startX = min(max(topR + 1, cutStartX), rect.width)
        let resolvedJoinX = min(max(startX + 10, joinX), rect.width)
        
        let topCutRadius: CGFloat = 18.0
        let bottomCutRadius = joinRadius

        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: startX, y: 0)
        let p3 = CGPoint(x: resolvedJoinX, y: bandY)
        let p4 = CGPoint(x: rect.width, y: bandY)
        let p5 = CGPoint(x: rect.width, y: rect.height)

        // Starting from bottom left (above corner)
        let START_P = CGPoint(x: 0, y: rect.height - bottomR)
        path.move(to: START_P)
        path.addLine(to: CGPoint(x: 0, y: topR))
        path.addArc(tangent1End: p1, tangent2End: p2, radius: topR)
        path.addArc(tangent1End: p2, tangent2End: p3, radius: topCutRadius)
        path.addArc(tangent1End: p3, tangent2End: p4, radius: bottomCutRadius)
        
        // Adds the rounded corner at the right edge where the folder's middle band area meets the right side (p4).
        let rightEdgeTopR: CGFloat = min(7.0, rect.height - bandY)
        if rightEdgeTopR > 0 && p4.x > p3.x {
            path.addArc(tangent1End: p4, tangent2End: p5, radius: rightEdgeTopR)
        } else {
            path.addLine(to: p4)
        }
        
        // Bottom Right Corner
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - bottomR))
        path.addArc(tangent1End: p5, tangent2End: CGPoint(x: rect.width - bottomR, y: rect.height), radius: bottomR)
        
        // Bottom Left Corner
        let p0 = CGPoint(x: 0, y: rect.height)
        path.addLine(to: CGPoint(x: bottomR, y: rect.height))
        path.addArc(tangent1End: p0, tangent2End: CGPoint(x: 0, y: rect.height - bottomR), radius: bottomR)

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
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY), radius: radius)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius), radius: radius)
        
        // Let it draw straight down to cover the right side corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

private struct ZDTagCollectionFolderSViewPreviewGallery: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                ForEach(CardThemeColor.allCases) { theme in
                    ZDTagCollectionFolderSView(
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

#Preview("Tag Folder SView - Light") {
    ZDTagCollectionFolderSViewPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Tag Folder SView - Dark") {
    ZDTagCollectionFolderSViewPreviewGallery()
        .preferredColorScheme(.dark)
}
