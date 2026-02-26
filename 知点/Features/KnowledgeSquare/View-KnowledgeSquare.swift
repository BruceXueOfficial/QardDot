import SwiftUI
import UIKit

private func cardTheme(for card: KnowledgeCard) -> CardThemeColor {
    card.themeColor ?? .defaultTheme
}

private enum KnowledgeSquareLayoutTuning {
    static let recentCardWidth: CGFloat = 164
    static let recentCardHeight: CGFloat = 146
    static let imageTruthCardWidth: CGFloat = recentCardWidth
    static let imageTruthCoverHeight: CGFloat = recentCardHeight

    static let bannerCardSpacing: CGFloat = 10
    static let recentCardSpacing: CGFloat = 10
    static let imageTruthCardSpacing: CGFloat = recentCardSpacing
}

private enum KnowledgeSquareShadowTuning {
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

struct KnowledgeSquareView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(ZDListRenderMode.storageKey) private var listRenderModeRawValue = ZDListRenderMode.defaultSelection.rawValue

    @State private var selectedCard: KnowledgeCard?
    @State private var featuredCardIDs: [UUID] = []
    @State private var randomCardIDs: [UUID] = []
    @State private var imageTruthItems: [KnowledgeSquareImageTruthItem] = []
    @State private var bannerCardMeasuredHeight: CGFloat = KnowledgeCardLViewTokens.bannerSize.height
    @State private var recentCardMeasuredHeight: CGFloat = KnowledgeCardMViewTokens.surfaceSize.height + 38
    @State private var imageTruthCardMeasuredHeight: CGFloat = KnowledgeSquareLayoutTuning.imageTruthCoverHeight + 42
    @State private var bannerContentFrame: CGRect = .zero
    @State private var bannerViewportWidth: CGFloat = 0
    @State private var recentContentFrame: CGRect = .zero
    @State private var recentViewportWidth: CGFloat = 0
    @State private var imageTruthContentFrame: CGRect = .zero
    @State private var imageTruthViewportWidth: CGFloat = 0

    private var selectedListRenderMode: ZDListRenderMode {
        ZDListRenderMode.resolve(rawValue: listRenderModeRawValue)
    }

    private var renderProfile: ZDListRenderProfile {
        selectedListRenderMode.profile
    }

    private enum KnowledgeSquareSpacing {
        static let moduleHeaderToContent: CGFloat = 10
    }

    private var horizontalSectionBottomInset: CGFloat {
        renderProfile.showsSecondaryShadow ? 12 : 8
    }

    private func horizontalSectionFrameHeight(for measuredCardHeight: CGFloat) -> CGFloat {
        let cardHeight = max(88, min(measuredCardHeight, 360))
        return cardHeight + horizontalSectionBottomInset
    }

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
            .environment(\.zdListRenderMode, selectedListRenderMode)
            .environment(\.zdListRenderScope, .knowledgeSquare)
        }
        .sheet(item: $selectedCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .onAppear {
            refreshFeaturedCardsIfNeeded()
            refreshCachedSections()
        }
        .onChange(of: library.cards.map(\.id)) { _, _ in
            refreshFeaturedCardsIfNeeded()
            refreshCachedSections()
        }
        .onChange(of: library.cards.map(\.updatedAt)) { _, _ in
            refreshCachedSections()
        }
    }

    private var bannerSection: some View {
        let frameHeight = horizontalSectionFrameHeight(for: bannerCardMeasuredHeight)

        return VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
            ZDSectionHeader("推荐卡片")

            ScrollView(.horizontal, showsIndicators: false) {
                if renderProfile.tracksEdgeFade {
                    HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.bannerCardSpacing) {
                        ForEach(Array(featuredCards.enumerated()), id: \.element.id) { index, card in
                            Button {
                                openCard(card)
                            } label: {
                                KnowledgeCardLView(
                                    card: card,
                                    viewCount: library.viewCounts[card.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                            .background(
                                Group {
                                    if index == 0 {
                                        GeometryReader { proxy in
                                            Color.clear.preference(
                                                key: BannerCardHeightKey.self,
                                                value: proxy.size.height
                                            )
                                        }
                                    }
                                }
                            )
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
                } else {
                    HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.bannerCardSpacing) {
                        ForEach(Array(featuredCards.enumerated()), id: \.element.id) { index, card in
                            Button {
                                openCard(card)
                            } label: {
                                KnowledgeCardLView(
                                    card: card,
                                    viewCount: library.viewCounts[card.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                            .background(
                                Group {
                                    if index == 0 {
                                        GeometryReader { proxy in
                                            Color.clear.preference(
                                                key: BannerCardHeightKey.self,
                                                value: proxy.size.height
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.bottom, horizontalSectionBottomInset)
            .coordinateSpace(name: "bannerScrollSpace")
            .background(
                Group {
                    if renderProfile.tracksEdgeFade {
                        GeometryReader { proxy in
                            Color.clear.preference(key: HorizontalViewportWidthKey.self, value: proxy.size.width)
                        }
                    }
                }
            )
            .onPreferenceChange(HorizontalContentFrameKey.self) { frame in
                if renderProfile.tracksEdgeFade {
                    bannerContentFrame = frame
                }
            }
            .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                if renderProfile.tracksEdgeFade {
                    bannerViewportWidth = width
                }
            }
            .onPreferenceChange(BannerCardHeightKey.self) { height in
                if height > 1 {
                    bannerCardMeasuredHeight = height
                }
            }
            .overlay(alignment: .leading) {
                if renderProfile.tracksEdgeFade, bannerContentFrame.minX < -1 {
                    edgeFadeOverlay(leading: true, style: renderProfile.edgeFadeStyle)
                }
            }
            .overlay(alignment: .trailing) {
                if renderProfile.tracksEdgeFade, bannerContentFrame.maxX > bannerViewportWidth + 1 {
                    edgeFadeOverlay(leading: false, style: renderProfile.edgeFadeStyle)
                }
            }
            .scrollClipDisabled()
            .frame(height: frameHeight)
        }
    }

    private var featuredCards: [KnowledgeCard] {
        let cardByID = Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) })
        return featuredCardIDs.compactMap { cardByID[$0] }
    }

    private var recentSection: some View {
        let frameHeight = horizontalSectionFrameHeight(for: recentCardMeasuredHeight)

        return VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
            ZDSectionHeader("最近添加")

            ScrollView(.horizontal, showsIndicators: false) {
                if renderProfile.tracksEdgeFade {
                    HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                        ForEach(Array(library.recentlyAdded(limit: 6).enumerated()), id: \.element.id) { index, card in
                            Button {
                                openCard(card)
                            } label: {
                                KnowledgeCardMView(
                                    card: card,
                                    viewCount: library.viewCounts[card.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                            .background(
                                Group {
                                    if index == 0 {
                                        GeometryReader { proxy in
                                            Color.clear.preference(
                                                key: RecentCardHeightKey.self,
                                                value: proxy.size.height
                                            )
                                        }
                                    }
                                }
                            )
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
                } else {
                    HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                        ForEach(Array(library.recentlyAdded(limit: 6).enumerated()), id: \.element.id) { index, card in
                            Button {
                                openCard(card)
                            } label: {
                                KnowledgeCardMView(
                                    card: card,
                                    viewCount: library.viewCounts[card.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                            .background(
                                Group {
                                    if index == 0 {
                                        GeometryReader { proxy in
                                            Color.clear.preference(
                                                key: RecentCardHeightKey.self,
                                                value: proxy.size.height
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.bottom, horizontalSectionBottomInset)
            .coordinateSpace(name: "recentScrollSpace")
            .background(
                Group {
                    if renderProfile.tracksEdgeFade {
                        GeometryReader { proxy in
                            Color.clear.preference(key: HorizontalViewportWidthKey.self, value: proxy.size.width)
                        }
                    }
                }
            )
            .onPreferenceChange(HorizontalContentFrameKey.self) { frame in
                if renderProfile.tracksEdgeFade {
                    recentContentFrame = frame
                }
            }
            .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                if renderProfile.tracksEdgeFade {
                    recentViewportWidth = width
                }
            }
            .onPreferenceChange(RecentCardHeightKey.self) { height in
                if height > 1 {
                    recentCardMeasuredHeight = height
                }
            }
            .overlay(alignment: .leading) {
                if renderProfile.tracksEdgeFade, recentContentFrame.minX < -1 {
                    edgeFadeOverlay(leading: true, style: renderProfile.edgeFadeStyle)
                }
            }
            .overlay(alignment: .trailing) {
                if renderProfile.tracksEdgeFade, recentContentFrame.maxX > recentViewportWidth + 1 {
                    edgeFadeOverlay(leading: false, style: renderProfile.edgeFadeStyle)
                }
            }
            .scrollClipDisabled()
            .frame(height: frameHeight)
        }
    }

    @ViewBuilder
    private var imageTruthSection: some View {
        if !imageTruthItems.isEmpty {
            let frameHeight = horizontalSectionFrameHeight(for: imageTruthCardMeasuredHeight)

            VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
                Text("图文并茂")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.9))

                ScrollView(.horizontal, showsIndicators: false) {
                    if renderProfile.tracksEdgeFade {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.imageTruthCardSpacing) {
                            ForEach(Array(imageTruthItems.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    openCard(item.card)
                                } label: {
                                    KnowledgeSquareImageTruthCard(
                                        title: item.card.title,
                                        source: item.source
                                    )
                                }
                                .buttonStyle(.plain)
                                .background(
                                    Group {
                                        if index == 0 {
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: ImageTruthCardHeightKey.self,
                                                    value: proxy.size.height
                                                )
                                            }
                                        }
                                    }
                                )
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
                    } else {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.imageTruthCardSpacing) {
                            ForEach(Array(imageTruthItems.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    openCard(item.card)
                                } label: {
                                    KnowledgeSquareImageTruthCard(
                                        title: item.card.title,
                                        source: item.source
                                    )
                                }
                                .buttonStyle(.plain)
                                .background(
                                    Group {
                                        if index == 0 {
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: ImageTruthCardHeightKey.self,
                                                    value: proxy.size.height
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, horizontalSectionBottomInset)
                .coordinateSpace(name: "imageTruthScrollSpace")
                .background(
                    Group {
                        if renderProfile.tracksEdgeFade {
                            GeometryReader { proxy in
                                Color.clear.preference(key: HorizontalViewportWidthKey.self, value: proxy.size.width)
                            }
                        }
                    }
                )
                .onPreferenceChange(HorizontalContentFrameKey.self) { frame in
                    if renderProfile.tracksEdgeFade {
                        imageTruthContentFrame = frame
                    }
                }
                .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                    if renderProfile.tracksEdgeFade {
                        imageTruthViewportWidth = width
                    }
                }
                .onPreferenceChange(ImageTruthCardHeightKey.self) { height in
                    if height > 1 {
                        imageTruthCardMeasuredHeight = height
                    }
                }
                .overlay(alignment: .leading) {
                    if renderProfile.tracksEdgeFade, imageTruthContentFrame.minX < -1 {
                        edgeFadeOverlay(leading: true, style: renderProfile.edgeFadeStyle)
                    }
                }
                .overlay(alignment: .trailing) {
                    if renderProfile.tracksEdgeFade, imageTruthContentFrame.maxX > imageTruthViewportWidth + 1 {
                        edgeFadeOverlay(leading: false, style: renderProfile.edgeFadeStyle)
                    }
                }
                .scrollClipDisabled()
                .frame(height: frameHeight)
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
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

    private var randomCards: [KnowledgeCard] {
        let cardByID = Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) })
        return randomCardIDs.compactMap { cardByID[$0] }
    }

    private var randomSection: some View {
        VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
            ZDSectionHeader("随机发现")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(randomCards) { card in
                    Button {
                        openCard(card)
                    } label: {
                        KnowledgeCardFView(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
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

    private func refreshCachedSections() {
        refreshRandomCards()
        refreshImageTruthItems()
    }

    private func refreshRandomCards() {
        randomCardIDs = Array(library.cards.shuffled().prefix(3)).map(\.id)
    }

    private func refreshImageTruthItems() {
        imageTruthItems = library.cards
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

    private func formattedDay(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func edgeFadeOverlay(leading: Bool, style: ZDListEdgeFadeStyle) -> some View {
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

            if style == .glass {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.45 : 0.65)
                    .mask(mask)
            }
        }
            .frame(width: renderProfile.edgeFadeWidth)
            .blur(radius: style == .glass ? renderProfile.edgeFadeBlurRadius : 0)
            .allowsHitTesting(false)
    }
}

private struct BannerCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct RecentCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ImageTruthCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
        KnowledgeSquareImageDecodeCache.image(for: source) {
            if source.hasPrefix("file://") {
                let path = String(source.dropFirst("file://".count))
                return UIImage(contentsOfFile: path)
            }
            if source.hasPrefix("/") {
                return UIImage(contentsOfFile: source)
            }
            return dataURIImage(source)
        }
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

private enum KnowledgeSquareImageDecodeCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        return cache
    }()

    static func image(for source: String, loader: () -> UIImage?) -> UIImage? {
        let key = cacheKey(for: source)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let loaded = loader() else {
            return nil
        }
        cache.setObject(loaded, forKey: key)
        return loaded
    }

    private static func cacheKey(for source: String) -> NSString {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("data:") {
            return NSString(string: "data:\(trimmed.hashValue)")
        }
        return NSString(string: trimmed)
    }
}

// MARK: - Mini Card

private struct KnowledgeSquareMiniCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard

    private var theme: CardThemeColor {
        cardTheme(for: card)
    }

    private var metrics: ZDPunchedCardMetrics {
        ZDPunchedCardMetrics(cornerRadius: 12, holeScale: 0.96)
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
            .zdPunchedGlassBackground(
                theme.cardBackgroundGradient,
                metrics: metrics,
                borderGradient: theme.cardBorderGradient
            )
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
