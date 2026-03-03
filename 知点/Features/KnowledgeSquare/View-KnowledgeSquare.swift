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
    @Environment(\.zdListRenderProfile) private var renderProfile

    @State private var selectedCard: KnowledgeCard?
    @State private var showProfileSheet = false
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
    @State private var recentlyViewedCardMeasuredHeight: CGFloat = 110 + 38
    @State private var recentlyViewedContentFrame: CGRect = .zero
    @State private var recentlyViewedViewportWidth: CGFloat = 0
    @State private var tagCollectionCardMeasuredHeight: CGFloat = KnowledgeCardMViewTokens.surfaceSize.height + 10
    @State private var tagCollectionContentFrame: CGRect = .zero
    @State private var tagCollectionViewportWidth: CGFloat = 0
    @State private var imageTruthContentFrame: CGRect = .zero
    @State private var imageTruthViewportWidth: CGFloat = 0

    private enum KnowledgeSquareSpacing {
        static let moduleHeaderToContent: CGFloat = 8
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
            ZDPageScaffold(
                title: "知识广场",
                titleTrailing: { profileButton }
            ) {
                bannerSection
                recentSection
                recentlyViewedSection
                tagCollectionSection
                imageTruthSection
                popularSection
                yesterdaySection
                randomSection
                statsSection
            }
            .environment(\.zdListRenderScope, .knowledgeSquare)
        }
        .sheet(item: $selectedCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
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
    private var recentlyViewedSection: some View {
        let cards = library.recentlyViewed(limit: 6)
        if !cards.isEmpty {
            let frameHeight = horizontalSectionFrameHeight(for: recentlyViewedCardMeasuredHeight)

            VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
                ZDSectionHeader("最近查看")

                ScrollView(.horizontal, showsIndicators: false) {
                    if renderProfile.tracksEdgeFade {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                Button {
                                    openCard(card)
                                } label: {
                                    KnowledgeCardSView(card: card)
                                        .frame(width: KnowledgeSquareLayoutTuning.recentCardWidth)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    Group {
                                        if index == 0 {
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: RecentlyViewedCardHeightKey.self,
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
                                    value: proxy.frame(in: .named("recentlyViewedScrollSpace"))
                                )
                            }
                        )
                    } else {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                Button {
                                    openCard(card)
                                } label: {
                                    KnowledgeCardSView(card: card)
                                        .frame(width: KnowledgeSquareLayoutTuning.recentCardWidth)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    Group {
                                        if index == 0 {
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: RecentlyViewedCardHeightKey.self,
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
                .coordinateSpace(name: "recentlyViewedScrollSpace")
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
                        recentlyViewedContentFrame = frame
                    }
                }
                .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                    if renderProfile.tracksEdgeFade {
                        recentlyViewedViewportWidth = width
                    }
                }
                .onPreferenceChange(RecentlyViewedCardHeightKey.self) { height in
                    if height > 1 {
                        recentlyViewedCardMeasuredHeight = height
                    }
                }
                .overlay(alignment: .leading) {
                    if renderProfile.tracksEdgeFade, recentlyViewedContentFrame.minX < -1 {
                        edgeFadeOverlay(leading: true, style: renderProfile.edgeFadeStyle)
                    }
                }
                .overlay(alignment: .trailing) {
                    if renderProfile.tracksEdgeFade, recentlyViewedContentFrame.maxX > recentlyViewedViewportWidth + 1 {
                        edgeFadeOverlay(leading: false, style: renderProfile.edgeFadeStyle)
                    }
                }
                .scrollClipDisabled()
                .frame(height: frameHeight)
            }
        }
    }

    private var tagCollectionGroups: [(model: ZDTagCollectionFolderModel, cards: [KnowledgeCard])] {
        var tagDict: [String: [KnowledgeCard]] = [:]
        for card in library.cards {
            let tags = (card.tags ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if tags.isEmpty {
                // Ignore empty tags for collection
            } else {
                for tag in tags {
                    tagDict[tag, default: []].append(card)
                }
            }
        }
        
        let groups = tagDict.map { (tag: $0.key, cards: $0.value.sorted { $0.createdAt < $1.createdAt }) }
        return groups.map { (model: modelForTagFolder(tag: $0.tag, cards: $0.cards), cards: $0.cards) }
                     .sorted { $0.model.cardCount > $1.model.cardCount }
    }

    private func modelForTagFolder(tag: String, cards: [KnowledgeCard]) -> ZDTagCollectionFolderModel {
        var textCount = 0
        var imageCount = 0
        var codeCount = 0
        var linkCount = 0
        var formulaCount = 0
        var viewCount = 0

        for card in cards {
            let cardViewCount = library.viewCounts[card.id] ?? 0
            viewCount += cardViewCount
            if let modules = card.modules ?? card.blocks {
                for module in modules {
                    switch module.kind {
                    case .text: textCount += 1
                    case .image: imageCount += 1
                    case .code: codeCount += 1
                    case .link: linkCount += 1
                    case .formula: formulaCount += 1
                    case .linkedCard: break
                    }
                }
            } else {
                if !card.content.isEmpty { textCount += 1 }
                imageCount += card.images?.count ?? 0
                codeCount += card.codeSnippets?.count ?? 0
                linkCount += card.links?.count ?? 0
            }
        }

        var addedDateText = "无"
        if let latestCard = cards.max(by: { $0.createdAt < $1.createdAt }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            formatter.locale = Locale(identifier: "en_US")
            addedDateText = formatter.string(from: latestCard.createdAt)
        }

        return ZDTagCollectionFolderModel(
            tagName: tag,
            cardCount: cards.count,
            textModuleCount: textCount,
            imageModuleCount: imageCount,
            codeModuleCount: codeCount,
            linkModuleCount: linkCount,
            formulaModuleCount: formulaCount,
            addedDateText: addedDateText,
            viewCount: viewCount
        )
    }

    @ViewBuilder
    private var tagCollectionSection: some View {
        let groups = tagCollectionGroups
        if !groups.isEmpty {
            let frameHeight = horizontalSectionFrameHeight(for: tagCollectionCardMeasuredHeight)

            VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
                ZDSectionHeader("标签荟萃")

                ScrollView(.horizontal, showsIndicators: false) {
                    if renderProfile.tracksEdgeFade {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                            ForEach(Array(groups.enumerated()), id: \.element.model.tagName) { index, group in
                                NavigationLink {
                                    TagFolderDetailCardsView(title: group.model.tagName, originalCards: group.cards, folderModel: group.model)
                                } label: {
                                    ZDTagCollectionFolderStyleCard(
                                        model: group.model,
                                        theme: library.tagColor(for: group.model.tagName)
                                    )
                                    .background(
                                        Group {
                                            if index == 0 {
                                                GeometryReader { proxy in
                                                    Color.clear.preference(
                                                        key: TagCollectionCardHeightKey.self,
                                                        value: proxy.size.height
                                                    )
                                                }
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: HorizontalContentFrameKey.self,
                                    value: proxy.frame(in: .named("tagCollectionScrollSpace"))
                                )
                            }
                        )
                    } else {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                            ForEach(Array(groups.enumerated()), id: \.element.model.tagName) { index, group in
                                NavigationLink {
                                    TagFolderDetailCardsView(title: group.model.tagName, originalCards: group.cards, folderModel: group.model)
                                } label: {
                                    ZDTagCollectionFolderStyleCard(
                                        model: group.model,
                                        theme: library.tagColor(for: group.model.tagName)
                                    )
                                    .background(
                                        Group {
                                            if index == 0 {
                                                GeometryReader { proxy in
                                                    Color.clear.preference(
                                                        key: TagCollectionCardHeightKey.self,
                                                        value: proxy.size.height
                                                    )
                                                }
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, horizontalSectionBottomInset)
                .coordinateSpace(name: "tagCollectionScrollSpace")
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
                        tagCollectionContentFrame = frame
                    }
                }
                .onPreferenceChange(HorizontalViewportWidthKey.self) { width in
                    if renderProfile.tracksEdgeFade {
                        tagCollectionViewportWidth = width
                    }
                }
                .onPreferenceChange(TagCollectionCardHeightKey.self) { height in
                    if height > 1 {
                        tagCollectionCardMeasuredHeight = height
                    }
                }
                .overlay(alignment: .leading) {
                    if renderProfile.tracksEdgeFade, tagCollectionContentFrame.minX < -1 {
                        edgeFadeOverlay(leading: true, style: renderProfile.edgeFadeStyle)
                    }
                }
                .overlay(alignment: .trailing) {
                    if renderProfile.tracksEdgeFade, tagCollectionContentFrame.maxX > tagCollectionViewportWidth + 1 {
                        edgeFadeOverlay(leading: false, style: renderProfile.edgeFadeStyle)
                    }
                }
                .scrollClipDisabled()
                .frame(height: frameHeight)
            }
        }
    }

    @ViewBuilder
    private var imageTruthSection: some View {
        if !imageTruthItems.isEmpty {
            let frameHeight = horizontalSectionFrameHeight(for: imageTruthCardMeasuredHeight)

            VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
                ZDSectionHeader("图文并茂")

                ScrollView(.horizontal, showsIndicators: false) {
                    if renderProfile.tracksEdgeFade {
                        HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.imageTruthCardSpacing) {
                            ForEach(Array(imageTruthItems.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    openCard(item.card)
                                } label: {
                                    KnowledgeSquareImageTruthCard(
                                        card: item.card,
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
                                        card: item.card,
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

    private var profileButton: some View {
        ZDProfileEntryButton {
            showProfileSheet = true
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

    @ViewBuilder
    private var yesterdaySection: some View {
        let cards = yesterdayCards
        if !cards.isEmpty {
            let frameHeight = horizontalSectionFrameHeight(for: KnowledgeCardMViewTokens.surfaceSize.height + 38)

            VStack(alignment: .leading, spacing: KnowledgeSquareSpacing.moduleHeaderToContent) {
                ZDSectionHeader("昨日添加")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: KnowledgeSquareLayoutTuning.recentCardSpacing) {
                        ForEach(cards) { card in
                            Button {
                                openCard(card)
                            } label: {
                                KnowledgeCardMView(
                                    card: card,
                                    viewCount: library.viewCounts[card.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, horizontalSectionBottomInset)
                .scrollClipDisabled()
                .frame(height: frameHeight)
            }
        }
    }

    private var randomCards: [KnowledgeCard] {
        let cardByID = Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) })
        return randomCardIDs.compactMap { cardByID[$0] }
    }

    private var yesterdayCards: [KnowledgeCard] {
        let calendar = Calendar.current
        return library.cards
            .filter { calendar.isDateInYesterday($0.createdAt) }
            .sorted { $0.createdAt > $1.createdAt }
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

private struct RecentlyViewedCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TagCollectionCardHeightKey: PreferenceKey {
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

    let card: KnowledgeCard
    let source: String

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

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(tagSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("file://") {
                let path = URL(string: trimmed)?.path ?? String(trimmed.dropFirst("file://".count))
                if let image = UIImage(contentsOfFile: path) {
                    return image
                }
                return resolveModuleImageFromCurrentDocuments(using: path)
            }
            if trimmed.hasPrefix("/") {
                if let image = UIImage(contentsOfFile: trimmed) {
                    return image
                }
                return resolveModuleImageFromCurrentDocuments(using: trimmed)
            }
            if let image = resolveModuleImageFromCurrentDocuments(using: trimmed) {
                return image
            }
            return dataURIImage(trimmed)
        }
    }

    private func resolveModuleImageFromCurrentDocuments(using rawSource: String) -> UIImage? {
        let trimmed = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (trimmed as NSString).lastPathComponent
        guard !filename.isEmpty else {
            return nil
        }

        let hintsModuleImage = trimmed.contains("ModuleImages/")
            || filename.hasPrefix("module-image-")
            || filename.hasPrefix("imported-image-")
        guard hintsModuleImage else {
            return nil
        }

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let currentPath = docsDir
            .appendingPathComponent("ModuleImages", isDirectory: true)
            .appendingPathComponent(filename)
            .path
        return UIImage(contentsOfFile: currentPath)
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
