import SwiftUI
import UIKit

private func cardTheme(for card: KnowledgeCard) -> CardThemeColor {
    card.themeColor ?? .defaultTheme
}

private struct PunchedCardMetrics {
    let cornerRadius: CGFloat
    let holeSize: CGFloat
    let holeInset: CGFloat

    init(cornerRadius: CGFloat, holeScale: CGFloat = 1) {
        self.cornerRadius = cornerRadius
        self.holeSize = max(5.4, cornerRadius * 0.6875 * holeScale)
        self.holeInset = max(4.4, cornerRadius * 0.5833 * holeScale)
    }
}

private enum KnowledgeSquareLayoutTuning {
    static let bannerCardWidth: CGFloat = 252
    static let bannerCardHeight: CGFloat = 248
    static let recentCardWidth: CGFloat = 164
    static let recentCardHeight: CGFloat = 146
    static let imageTruthCardWidth: CGFloat = recentCardWidth
    static let imageTruthCoverHeight: CGFloat = recentCardHeight

    static let bannerCardSpacing: CGFloat = 10
    static let recentCardSpacing: CGFloat = 10
    static let imageTruthCardSpacing: CGFloat = recentCardSpacing
}

private enum KnowledgeSquareShadowTuning {
    static let bannerBaseLightOpacity: Double = 0.09
    static let bannerBaseDarkOpacity: Double = 0.24
    static let bannerBaseLightRadius: CGFloat = 5
    static let bannerBaseDarkRadius: CGFloat = 7
    static let bannerBaseLightY: CGFloat = 4
    static let bannerBaseDarkY: CGFloat = 5

    static let bannerTintLightOpacity: Double = 0.10
    static let bannerTintDarkOpacity: Double = 0.24
    static let bannerTintLightRadius: CGFloat = 3
    static let bannerTintDarkRadius: CGFloat = 4
    static let bannerTintY: CGFloat = 2

    static let miniBaseLightOpacity: Double = 0.10
    static let miniBaseDarkOpacity: Double = 0.24
    static let miniBaseLightRadius: CGFloat = 5
    static let miniBaseDarkRadius: CGFloat = 7
    static let miniBaseLightY: CGFloat = 3
    static let miniBaseDarkY: CGFloat = 4

    static let miniTintLightOpacity: Double = 0.10
    static let miniTintDarkOpacity: Double = 0.16
    static let miniTintLightRadius: CGFloat = 2
    static let miniTintDarkRadius: CGFloat = 3
    static let miniTintY: CGFloat = 1
}

private struct KnowledgeSquarePunchedCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let theme: CardThemeColor
    let metrics: PunchedCardMetrics

    func body(content: Content) -> some View {
        content
            .background(
                TitleCardPunchedShape(
                    cornerRadius: metrics.cornerRadius,
                    holeSize: metrics.holeSize,
                    holeInset: metrics.holeInset
                )
                .fill(theme.cardBackgroundGradient, style: FillStyle(eoFill: true))
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .overlay(
                TitleCardPunchedShape(
                    cornerRadius: metrics.cornerRadius,
                    holeSize: metrics.holeSize,
                    holeInset: metrics.holeInset
                )
                .stroke(theme.cardBorderGradient.opacity(0.58), lineWidth: 0.78)
            )
            .overlay(
                TitleCardPunchedShape(
                    cornerRadius: metrics.cornerRadius,
                    holeSize: metrics.holeSize,
                    holeInset: metrics.holeInset
                )
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.2),
                    lineWidth: 0.4
                )
                .padding(1)
            )
            .overlay(alignment: .topTrailing) {
                KnowledgeCardPinHoleInnerShadow(size: metrics.holeSize)
                    .padding(.top, metrics.holeInset)
                    .padding(.trailing, metrics.holeInset)
                    .allowsHitTesting(false)
            }
    }
}

private extension View {
    func knowledgeSquarePunchedCard(theme: CardThemeColor, metrics: PunchedCardMetrics) -> some View {
        modifier(KnowledgeSquarePunchedCardStyle(theme: theme, metrics: metrics))
    }
}

struct KnowledgeSquareView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedCard: KnowledgeCard?
    @State private var featuredCardIDs: [UUID] = []
    @State private var bannerContentFrame: CGRect = .zero
    @State private var bannerViewportWidth: CGFloat = 0
    @State private var recentContentFrame: CGRect = .zero
    @State private var recentViewportWidth: CGFloat = 0
    @State private var imageTruthContentFrame: CGRect = .zero
    @State private var imageTruthViewportWidth: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: "知识广场") {
                bannerSection
                recentSection
                imageTruthSection
                popularSection
                randomSection
                statsSection
            }
        }
        .sheet(item: $selectedCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .onAppear(perform: refreshFeaturedCardsIfNeeded)
        .onChange(of: library.cards.map(\.id)) { _, _ in
            refreshFeaturedCardsIfNeeded()
        }
    }

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZDSectionHeader("推荐卡片")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.bannerCardSpacing) {
                    ForEach(featuredCards) { card in
                        Button {
                            openCard(card)
                        } label: {
                            KnowledgeSquareBannerCard(
                                card: card,
                                viewCount: library.viewCounts[card.id] ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: HorizontalContentFrameKey.self,
                            value: proxy.frame(in: .named("bannerScrollSpace"))
                        )
                    }
                )
            }
            .coordinateSpace(name: "bannerScrollSpace")
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: HorizontalViewportWidthKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(HorizontalContentFrameKey.self) { frame in
                bannerContentFrame = frame
            }
            .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                bannerViewportWidth = width
            }
            .overlay(alignment: .leading) {
                if bannerContentFrame.minX < -1 {
                    edgeFadeOverlay(leading: true)
                }
            }
            .overlay(alignment: .trailing) {
                if bannerContentFrame.maxX > bannerViewportWidth + 1 {
                    edgeFadeOverlay(leading: false)
                }
            }
            .scrollClipDisabled()
            .frame(height: KnowledgeSquareLayoutTuning.bannerCardHeight)
        }
    }

    private var featuredCards: [KnowledgeCard] {
        let cardByID = Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) })
        return featuredCardIDs.compactMap { cardByID[$0] }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZDSectionHeader("最近添加")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                    ForEach(library.recentlyAdded(limit: 6)) { card in
                        Button {
                            openCard(card)
                        } label: {
                            KnowledgeSquareMiniCard(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: HorizontalContentFrameKey.self,
                            value: proxy.frame(in: .named("recentScrollSpace"))
                        )
                    }
                )
            }
            .coordinateSpace(name: "recentScrollSpace")
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: HorizontalViewportWidthKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(HorizontalContentFrameKey.self) { frame in
                recentContentFrame = frame
            }
            .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                recentViewportWidth = width
            }
            .overlay(alignment: .leading) {
                if recentContentFrame.minX < -1 {
                    edgeFadeOverlay(leading: true)
                }
            }
            .overlay(alignment: .trailing) {
                if recentContentFrame.maxX > recentViewportWidth + 1 {
                    edgeFadeOverlay(leading: false)
                }
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private var imageTruthSection: some View {
        if !cardsWithImagesByCreatedAtAscending.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("有图有真相")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.9))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.imageTruthCardSpacing) {
                        ForEach(cardsWithImagesByCreatedAtAscending) { item in
                            Button {
                                openCard(item.card)
                            } label: {
                                KnowledgeSquareImageTruthCard(
                                    title: item.card.title,
                                    source: item.source
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: HorizontalContentFrameKey.self,
                                value: proxy.frame(in: .named("imageTruthScrollSpace"))
                            )
                        }
                    )
                }
                .coordinateSpace(name: "imageTruthScrollSpace")
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HorizontalViewportWidthKey.self, value: proxy.size.width)
                    }
                )
                .onPreferenceChange(HorizontalContentFrameKey.self) { frame in
                    imageTruthContentFrame = frame
                }
                .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                    imageTruthViewportWidth = width
                }
                .overlay(alignment: .leading) {
                    if imageTruthContentFrame.minX < -1 {
                        edgeFadeOverlay(leading: true)
                    }
                }
                .overlay(alignment: .trailing) {
                    if imageTruthContentFrame.maxX > imageTruthViewportWidth + 1 {
                        edgeFadeOverlay(leading: false)
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZDSectionHeader("最多浏览")

            VStack(spacing: 10) {
                ForEach(Array(library.mostViewed(limit: 5).enumerated()), id: \.element.id) { index, card in
                    Button {
                        openCard(card)
                    } label: {
                        KnowledgeSquareRankRow(
                            rank: index + 1,
                            card: card,
                            viewCount: library.viewCounts[card.id] ?? 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cardsWithImagesByCreatedAtAscending: [KnowledgeSquareImageTruthItem] {
        library.cards
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.createdAt < rhs.createdAt
            }
            .compactMap { card in
                guard let source = firstImageSource(of: card) else {
                    return nil
                }
                return KnowledgeSquareImageTruthItem(card: card, source: source)
            }
    }

    private var randomSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZDSectionHeader("随机发现")

            VStack(alignment: .leading, spacing: 10) {
                let randomCards = Array(library.cards.shuffled().prefix(3))
                ForEach(randomCards) { card in
                    let theme = cardTheme(for: card)
                    let useLightCardText = theme.prefersLightForeground(in: colorScheme)
                    let metrics = PunchedCardMetrics(cornerRadius: 10, holeScale: 0.96)
                    Button {
                        openCard(card)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(useLightCardText ? Color.white.opacity(0.92) : Color.black.opacity(0.82))
                                .lineLimit(1)

                            Text(markdownExcerpt(of: card))
                                .font(.footnote)
                                .foregroundStyle(useLightCardText ? Color.white.opacity(0.82) : Color.black.opacity(0.56))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.leading, 10)
                        .padding(.trailing, 20)
                        .padding(.bottom, 10)
                        .knowledgeSquarePunchedCard(theme: theme, metrics: metrics)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(moduleSurface)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZDSectionHeader("知识统计")

            VStack(alignment: .leading, spacing: 0) {
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]

                LazyVGrid(columns: columns, spacing: 10) {
                    KnowledgeSquareStatTile(title: "卡片总量", value: "\(library.cards.count)")
                    KnowledgeSquareStatTile(title: "累计浏览", value: "\(library.totalViews)")
                    KnowledgeSquareStatTile(title: "文字模块", value: "\(library.textModuleCount)")
                    KnowledgeSquareStatTile(title: "图片模块", value: "\(library.imageModuleCount)")
                    KnowledgeSquareStatTile(title: "代码模块", value: "\(library.codeModuleCount)")
                    KnowledgeSquareStatTile(title: "链接模块", value: "\(library.linkModuleCount)")
                    KnowledgeSquareStatTile(
                        title: "最早收集",
                        value: formattedDay(library.firstCollectDate)
                    )
                    KnowledgeSquareStatTile(
                        title: "最近收集",
                        value: formattedDay(library.latestCollectDate)
                    )
                }
            }
            .padding(14)
            .background(moduleSurface)
        }
    }

    private var moduleSurface: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.clear)
            .zdGlassSurface(cornerRadius: 14, lineWidth: 0.84)
    }

    private func refreshFeaturedCardsIfNeeded() {
        guard !library.cards.isEmpty else {
            featuredCardIDs = []
            return
        }

        let currentIDs = Set(library.cards.map(\.id))
        let cachedIDs = Set(featuredCardIDs)
        if featuredCardIDs.isEmpty || cachedIDs != currentIDs {
            featuredCardIDs = Array(library.cards.shuffled().prefix(min(5, library.cards.count))).map(\.id)
        }
    }

    private func firstImageSource(of card: KnowledgeCard) -> String? {
        let modules = card.modules ?? card.blocks ?? []
        for module in modules where module.kind == .image {
            let fromArray = (module.imageURLs ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if let first = fromArray.first {
                return first
            }

            let single = (module.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !single.isEmpty {
                return single
            }
        }

        let legacy = (card.images ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return legacy
    }

    private func openCard(_ card: KnowledgeCard) {
        library.recordView(for: card)
        selectedCard = card
    }

    private func markdownExcerpt(of card: KnowledgeCard) -> AttributedString {
        let text = card.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return AttributedString("点击查看完整卡片内容")
        }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private func formattedDay(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func edgeFadeOverlay(leading: Bool) -> some View {
        let baseColor = Color.zdPageBase
        let mask = LinearGradient(
            colors: leading
                ? [Color.black.opacity(0.98), Color.black.opacity(0.1), .clear]
                : [.clear, Color.black.opacity(0.1), Color.black.opacity(0.98)],
            startPoint: .leading,
            endPoint: .trailing
        )

        return ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: leading
                            ? [baseColor.opacity(0.98), baseColor.opacity(0.45), .clear]
                            : [.clear, baseColor.opacity(0.45), baseColor.opacity(0.98)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.45 : 0.65)
                .mask(mask)
        }
            .frame(width: 46)
            .blur(radius: 3.2)
            .allowsHitTesting(false)
    }
}

private struct HorizontalContentFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct HorizontalViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct KnowledgeSquareImageTruthItem: Identifiable {
    let card: KnowledgeCard
    let source: String

    var id: UUID { card.id }
}

private struct KnowledgeSquareImageTruthCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            KnowledgeSquareImageCover(source: source)
                .frame(
                    width: KnowledgeSquareLayoutTuning.imageTruthCardWidth,
                    height: KnowledgeSquareLayoutTuning.imageTruthCoverHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), lineWidth: 0.8)
                )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: KnowledgeSquareLayoutTuning.imageTruthCardWidth, alignment: .leading)
        }
        .frame(width: KnowledgeSquareLayoutTuning.imageTruthCardWidth, alignment: .leading)
    }
}

private struct KnowledgeSquareImageCover: View {
    let source: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.1))

            imageLayer
        }
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let image = localImage(source) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: source), url.scheme != nil {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "photo")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.86))
        }
    }

    private func localImage(_ source: String) -> UIImage? {
        if source.hasPrefix("file://") {
            let path = String(source.dropFirst("file://".count))
            return UIImage(contentsOfFile: path)
        }
        if source.hasPrefix("/") {
            return UIImage(contentsOfFile: source)
        }
        return dataURIImage(source)
    }

    private func dataURIImage(_ source: String) -> UIImage? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("data:"),
              let commaIndex = trimmed.firstIndex(of: ",") else {
            return nil
        }

        let metadataStart = trimmed.index(trimmed.startIndex, offsetBy: 5)
        let metadata = String(trimmed[metadataStart..<commaIndex]).lowercased()
        guard metadata.contains("base64"),
              metadata.contains("image/") else {
            return nil
        }

        let payload = String(trimmed[trimmed.index(after: commaIndex)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct AdaptiveTagChipRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let tags: [String]
    let chipTextColor: Color
    let useLightForeground: Bool
    let trailingReservedWidth: CGFloat

    private let chipFont = UIFont.systemFont(ofSize: 10, weight: .medium)
    private let overflowFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
    private let chipHorizontalPadding: CGFloat = 14
    private let chipSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let result = fittingResult(for: max(0, proxy.size.width - trailingReservedWidth))
            HStack(spacing: chipSpacing) {
                ForEach(result.visibleTags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(chipTextColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Color.white.opacity(
                                useLightForeground ? 0.18 : (colorScheme == .dark ? 0.1 : 0.46)
                            )
                        )
                        .clipShape(Capsule())
                }
                if result.hiddenCount > 0 {
                    Text("+\(result.hiddenCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(useLightForeground ? Color.white.opacity(0.76) : .secondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 22)
    }

    private func fittingResult(for availableWidth: CGFloat) -> (visibleTags: [String], hiddenCount: Int) {
        guard !tags.isEmpty, availableWidth > 0 else {
            return ([], tags.count)
        }

        let tagWidths = tags.map(measuredChipWidth(for:))
        let totalWidth = rowWidth(tagWidths: tagWidths, hiddenCount: 0)
        if totalWidth <= availableWidth {
            return (tags, 0)
        }

        var bestVisibleCount = 0
        for visibleCount in 0...tags.count {
            let hiddenCount = tags.count - visibleCount
            let visibleWidths = Array(tagWidths.prefix(visibleCount))
            let candidateWidth = rowWidth(tagWidths: visibleWidths, hiddenCount: hiddenCount)
            if candidateWidth <= availableWidth {
                bestVisibleCount = visibleCount
            } else {
                break
            }
        }

        let visible = Array(tags.prefix(bestVisibleCount))
        return (visible, max(0, tags.count - bestVisibleCount))
    }

    private func rowWidth(tagWidths: [CGFloat], hiddenCount: Int) -> CGFloat {
        guard !tagWidths.isEmpty || hiddenCount > 0 else { return 0 }

        let tagsWidth = tagWidths.reduce(0, +)
        let tagsSpacing = CGFloat(max(tagWidths.count - 1, 0)) * chipSpacing
        if hiddenCount == 0 {
            return tagsWidth + tagsSpacing
        }

        let overflowText = "+\(hiddenCount)" as NSString
        let overflowSize = overflowText.size(withAttributes: [.font: overflowFont])
        let overflowSpacing = tagWidths.isEmpty ? 0 : chipSpacing
        return tagsWidth + tagsSpacing + overflowSpacing + ceil(overflowSize.width)
    }

    private func measuredChipWidth(for text: String) -> CGFloat {
        let value = text as NSString
        let textSize = value.size(withAttributes: [.font: chipFont])
        return ceil(textSize.width) + chipHorizontalPadding
    }
}

// MARK: - Banner Card

private struct KnowledgeSquareBannerCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard
    let viewCount: Int

    private var renderedContent: AttributedString {
        (try? AttributedString(markdown: card.content)) ?? AttributedString(card.content)
    }

    private var theme: CardThemeColor {
        cardTheme(for: card)
    }

    private var metrics: PunchedCardMetrics {
        PunchedCardMetrics(cornerRadius: 18, holeScale: 1.02)
    }

    private var useLightCardText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    private var chipTextColor: Color {
        useLightCardText ? Color.white.opacity(0.9) : theme.primaryColor.opacity(0.9)
    }

    private var chipBackgroundColor: Color {
        Color.white.opacity(useLightCardText ? 0.18 : (colorScheme == .dark ? 0.1 : 0.46))
    }

    private var tags: [String] {
        (card.tags ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                AdaptiveTagChipRow(
                    tags: tags,
                    chipTextColor: chipTextColor,
                    useLightForeground: useLightCardText,
                    trailingReservedWidth: 34
                )
            } else {
                Text("未添加标签")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(chipTextColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(chipBackgroundColor)
                    .clipShape(Capsule())
            }

            Text(card.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(useLightCardText ? Color.white.opacity(0.94) : Color.black.opacity(0.84))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(renderedContent)
                .font(.subheadline)
                .foregroundStyle(useLightCardText ? Color.white.opacity(0.86) : Color.black.opacity(0.6))
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Label("\(viewCount)", systemImage: "eye.fill")
                Text(card.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(useLightCardText ? Color.white.opacity(0.82) : Color.black.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 12)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.bottom, 14)
        .frame(width: KnowledgeSquareLayoutTuning.bannerCardWidth)
        .frame(height: KnowledgeSquareLayoutTuning.bannerCardHeight, alignment: .topLeading)
        .knowledgeSquarePunchedCard(theme: theme, metrics: metrics)
        .shadow(
            color: Color.black.opacity(
                colorScheme == .dark
                    ? KnowledgeSquareShadowTuning.bannerBaseDarkOpacity
                    : KnowledgeSquareShadowTuning.bannerBaseLightOpacity
            ),
            radius: colorScheme == .dark
                ? KnowledgeSquareShadowTuning.bannerBaseDarkRadius
                : KnowledgeSquareShadowTuning.bannerBaseLightRadius,
            x: 0,
            y: colorScheme == .dark
                ? KnowledgeSquareShadowTuning.bannerBaseDarkY
                : KnowledgeSquareShadowTuning.bannerBaseLightY
        )
        .shadow(
            color: theme.primaryColor.opacity(
                colorScheme == .dark
                    ? KnowledgeSquareShadowTuning.bannerTintDarkOpacity
                    : KnowledgeSquareShadowTuning.bannerTintLightOpacity
            ),
            radius: colorScheme == .dark
                ? KnowledgeSquareShadowTuning.bannerTintDarkRadius
                : KnowledgeSquareShadowTuning.bannerTintLightRadius,
            x: 0,
            y: KnowledgeSquareShadowTuning.bannerTintY
        )
    }
}

// MARK: - Mini Card

private struct KnowledgeSquareMiniCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard

    private var theme: CardThemeColor {
        cardTheme(for: card)
    }

    private var metrics: PunchedCardMetrics {
        PunchedCardMetrics(cornerRadius: 12, holeScale: 0.96)
    }

    private var useLightCardText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    private var renderedContent: AttributedString {
        let text = card.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return AttributedString("点击查看完整卡片内容")
        }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private var tagSummary: String {
        let normalized = (card.tags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if normalized.isEmpty {
            return "未添加标签"
        }
        return normalized.joined(separator: "；")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 8) {
                Text(renderedContent)
                    .font(.footnote)
                    .foregroundStyle(useLightCardText ? Color.white.opacity(0.86) : Color.black.opacity(0.62))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 11)
            .padding(.leading, 11)
            .padding(.trailing, 13)
            .padding(.bottom, 11)
            .frame(
                width: KnowledgeSquareLayoutTuning.recentCardWidth,
                height: KnowledgeSquareLayoutTuning.recentCardHeight
            )
            .knowledgeSquarePunchedCard(theme: theme, metrics: metrics)
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark
                        ? KnowledgeSquareShadowTuning.miniBaseDarkOpacity
                        : KnowledgeSquareShadowTuning.miniBaseLightOpacity
                ),
                radius: colorScheme == .dark
                    ? KnowledgeSquareShadowTuning.miniBaseDarkRadius
                    : KnowledgeSquareShadowTuning.miniBaseLightRadius,
                x: 0,
                y: colorScheme == .dark
                    ? KnowledgeSquareShadowTuning.miniBaseDarkY
                    : KnowledgeSquareShadowTuning.miniBaseLightY
            )
            .shadow(
                color: theme.primaryColor.opacity(
                    colorScheme == .dark
                        ? KnowledgeSquareShadowTuning.miniTintDarkOpacity
                        : KnowledgeSquareShadowTuning.miniTintLightOpacity
                ),
                radius: colorScheme == .dark
                    ? KnowledgeSquareShadowTuning.miniTintDarkRadius
                    : KnowledgeSquareShadowTuning.miniTintLightRadius,
                x: 0,
                y: KnowledgeSquareShadowTuning.miniTintY
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.94))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(tagSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: KnowledgeSquareLayoutTuning.recentCardWidth, alignment: .leading)
    }
}

// MARK: - Rank Row

private struct KnowledgeSquareRankRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let rank: Int
    let card: KnowledgeCard
    let viewCount: Int

    private var theme: CardThemeColor {
        cardTheme(for: card)
    }

    private var useLightCardText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    var body: some View {
        let cornerRadius: CGFloat = 10

        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(useLightCardText ? Color.white.opacity(0.9) : theme.primaryColor.opacity(0.92))
                .frame(width: 20)

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(useLightCardText ? Color.white.opacity(0.94) : Color.black.opacity(0.84))
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "eye")
                Text("\(viewCount)")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(useLightCardText ? Color.white.opacity(0.82) : Color.black.opacity(0.54))
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(theme.cardBackgroundGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(theme.cardBorderGradient.opacity(0.58), lineWidth: 0.78)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.2),
                    lineWidth: 0.4
                )
                .padding(1)
        )
    }
}

// MARK: - Stat Tile

private struct KnowledgeSquareStatTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .zdGlassSurface(cornerRadius: 10, lineWidth: 1.12)
    }
}

#Preview("Knowledge Square") {
    KnowledgeSquareView()
        .environmentObject(KnowledgeCardLibraryStore())
}
