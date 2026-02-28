import SwiftUI

// MARK: - Sort Mode

enum CardSortMode: Equatable, RawRepresentable {
    case defaultSort
    case byTag(ascending: Bool)
    case byDate(ascending: Bool)
    case byColor

    var rawValue: String {
        switch self {
        case .defaultSort: return "defaultSort"
        case .byTag(let asc): return "byTag:\(asc)"
        case .byDate(let asc): return "byDate:\(asc)"
        case .byColor: return "byColor"
        }
    }

    init?(rawValue: String) {
        if rawValue == "defaultSort" { self = .defaultSort }
        else if rawValue.hasPrefix("byTag:") {
            self = .byTag(ascending: rawValue.hasSuffix("true"))
        }
        else if rawValue.hasPrefix("byDate:") {
            self = .byDate(ascending: rawValue.hasSuffix("true"))
        } else if rawValue == "byColor" {
            self = .byColor
        } else {
            return nil
        }
    }
}

enum WarehouseMode: String, Equatable {
    case cards
    case graphs
}

// MARK: - Main View

struct CardManagementView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @EnvironmentObject private var graphStore: KnowledgeGraphStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var selectedCard: KnowledgeCard?
    @State private var showProfileSheet = false

    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var deleteRequest: DeleteRequest?

    @AppStorage("CardManagement.SortMode") private var sortMode: CardSortMode = .defaultSort
    @AppStorage("CardManagement.WarehouseMode") private var warehouseMode: WarehouseMode = .cards

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            if warehouseMode == .cards {
                cardsWarehousePage
            } else {
                graphWarehousePage
            }
        }
        .onChange(of: warehouseMode) { _, mode in
            if mode == .graphs {
                isSelectionMode = false
                selectedIDs.removeAll()
                deleteRequest = nil
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
        }
        .sheet(item: $selectedCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .alert(
            "确认删除",
            isPresented: showDeleteAlert,
            presenting: deleteRequest
        ) { request in
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                library.deleteCards(ids: request.ids)
                selectedIDs.subtract(request.ids)
            }
        } message: { request in
            Text(request.message)
        }
    }

    private var cardsWarehousePage: some View {
        ZDPageScaffold(
            title: nil,
            bottomPadding: isSelectionMode ? 98 : 12,
            contentSpacing: 14
        ) {
            headerRow
            searchBar

            switch sortMode {
            case .defaultSort:
                defaultGridView
            case .byTag:
                tagGroupedView
            case .byDate:
                dateGroupedView
            case .byColor:
                colorGroupedView
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode {
                selectionToolbar
            }
        }
        .environment(\.zdListRenderScope, .warehouse)
        .onChange(of: displayCards.map(\.id)) { _, ids in
            selectedIDs.formIntersection(Set(ids))
        }
    }

    private var graphWarehousePage: some View {
        ZDPageScaffold(
            title: nil,
            bottomPadding: 16,
            contentSpacing: 14
        ) {
            headerRow
            GraphWarehouseView()
                .environmentObject(graphStore)
                .environmentObject(library)
        }
    }



    // MARK: - Delete Alert Binding

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { deleteRequest != nil },
            set: { presented in
                if !presented {
                    deleteRequest = nil
                }
            }
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Menu {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        warehouseMode = .cards
                    }
                } label: {
                    Label("卡片管理", systemImage: warehouseMode == .cards ? "checkmark" : "")
                }
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        warehouseMode = .graphs
                    }
                } label: {
                    Label("图谱管理", systemImage: warehouseMode == .graphs ? "checkmark" : "")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(warehouseMode == .cards ? "卡片管理" : "图谱管理")
                        .font(ZDTypographyScale.default.pageTitle)
                        .foregroundStyle(.primary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                if warehouseMode == .cards {
                    sortMenuButton
                    selectionButton
                } else {
                    ZDIconButton(
                        systemName: "plus",
                        active: false
                    ) {
                        NotificationCenter.default.post(name: .init("ShowGraphCreateSheet"), object: nil)
                    }
                }
                profileButton
            }
        }
        .padding(.top, 4)
    }

    private var sortMenuButton: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    sortMode = .defaultSort
                }
            } label: {
                Label("默认排列", systemImage: sortMode == .defaultSort ? "checkmark" : "")
            }

            Menu {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        sortMode = .byTag(ascending: true)
                    }
                } label: {
                    Label("升序排列", systemImage: sortMode == .byTag(ascending: true) ? "checkmark" : "")
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        sortMode = .byTag(ascending: false)
                    }
                } label: {
                    Label("降序排列", systemImage: sortMode == .byTag(ascending: false) ? "checkmark" : "")
                }
            } label: {
                Label("按照标签", systemImage: "tag")
            }

            Menu {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        sortMode = .byDate(ascending: true)
                    }
                } label: {
                    Label("升序排列", systemImage: sortMode == .byDate(ascending: true) ? "checkmark" : "")
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        sortMode = .byDate(ascending: false)
                    }
                } label: {
                    Label("降序排列", systemImage: sortMode == .byDate(ascending: false) ? "checkmark" : "")
                }
            } label: {
                Label("按照时间", systemImage: "clock")
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    sortMode = .byColor
                }
            } label: {
                Label("按照颜色", systemImage: sortMode == .byColor ? "checkmark" : "paintpalette")
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sortMode == .defaultSort ? .primary.opacity(0.85) : Color.zdAccentDeep)
                .frame(width: 36, height: 36)
                .background(
                    sortMode == .defaultSort
                        ? Color.clear
                        : Color.zdAccentDeep.opacity(colorScheme == .dark ? 0.2 : 0.16)
                )
                .zdInteractiveControlStyle(cornerRadius: 999)
        }
    }

    private var selectionButton: some View {
        ZDIconButton(
            systemName: isSelectionMode ? "xmark" : "checkmark.circle",
            active: isSelectionMode
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selectedIDs.removeAll()
                }
            }
        }
    }

    private var profileButton: some View {
        ZDProfileEntryButton {
            showProfileSheet = true
        }
    }

    // MARK: - Default Grid

    private var defaultGridView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayCards) { card in
                CardManagementSViewTile(
                    card: card,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedIDs.contains(card.id)
                )
                .onTapGesture {
                    handleCardTap(card)
                }
            }
        }
    }

    // MARK: - Tag Grouped View

    private var tagGroupedView: some View {
        let groups = cardsByTag
        return LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(groups, id: \.tag) { group in
                CardGroupSection(
                    title: group.tag,
                    cards: group.cards,
                    isSelectionMode: isSelectionMode,
                    selectedIDs: $selectedIDs,
                    onCardTap: handleCardTap
                )
            }
        }
    }

    // MARK: - Date Grouped View

    private var dateGroupedView: some View {
        let groups = cardsByDate
        return LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(groups, id: \.dateLabel) { group in
                CardGroupSection(
                    title: group.dateLabel,
                    cards: group.cards,
                    isSelectionMode: isSelectionMode,
                    selectedIDs: $selectedIDs,
                    onCardTap: handleCardTap
                )
            }
        }
    }

    // MARK: - Color Grouped View

    private var colorGroupedView: some View {
        let groups = cardsByColor
        return LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(groups, id: \.colorLabel) { group in
                CardGroupSection(
                    title: group.colorLabel,
                    cards: group.cards,
                    isSelectionMode: isSelectionMode,
                    selectedIDs: $selectedIDs,
                    onCardTap: handleCardTap
                )
            }
        }
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        let actionButtonWidth: CGFloat = 96
        let allSelected = !displayCards.isEmpty && selectedIDs.count == displayCards.count

        return ZDFloatingActionBar {
            ZDSecondaryButton(text: allSelected ? "取消全选" : "全选", fullWidth: false) {
                let visibleIDs = Set(displayCards.map(\.id))
                if !visibleIDs.isEmpty && selectedIDs == visibleIDs {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = visibleIDs
                }
            }
            .frame(width: actionButtonWidth)

            Text("已选 \(selectedIDs.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            ZDPrimaryButton(text: "删除", isDisabled: selectedIDs.isEmpty, fullWidth: false) {
                requestDelete(ids: selectedIDs, title: nil)
            }
            .frame(width: actionButtonWidth)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Data

    private var displayCards: [KnowledgeCard] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if keyword.isEmpty {
            return library.cards.sorted { $0.createdAt > $1.createdAt }
        } else {
            return library.cards
                .filter { $0.title.localizedCaseInsensitiveContains(keyword) }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var cardsByTag: [(tag: String, cards: [KnowledgeCard])] {
        let ascending: Bool
        if case .byTag(let asc) = sortMode { ascending = asc } else { ascending = true }

        var tagDict: [String: [KnowledgeCard]] = [:]
        for card in displayCards {
            let tags = (card.tags ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if tags.isEmpty {
                tagDict["未分类", default: []].append(card)
            } else {
                for tag in tags {
                    tagDict[tag, default: []].append(card)
                }
            }
        }

        // Sort cards within each tag by createdAt ascending
        var result = tagDict.map { (tag: $0.key, cards: $0.value.sorted { $0.createdAt < $1.createdAt }) }

        // Sort tags by first character
        result.sort { lhs, rhs in
            let lKey = lhs.tag.localizedLowercase
            let rKey = rhs.tag.localizedLowercase
            if lKey == "未分类" { return !ascending }
            if rKey == "未分类" { return ascending }
            return ascending ? lKey < rKey : lKey > rKey
        }

        return result
    }

    private var cardsByDate: [(dateLabel: String, cards: [KnowledgeCard])] {
        let ascending: Bool
        if case .byDate(let asc) = sortMode { ascending = asc } else { ascending = true }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"

        var dateDict: [String: (date: Date, cards: [KnowledgeCard])] = [:]
        for card in displayCards {
            let key = formatter.string(from: card.createdAt)
            if dateDict[key] != nil {
                dateDict[key]!.cards.append(card)
            } else {
                dateDict[key] = (date: Calendar.current.startOfDay(for: card.createdAt), cards: [card])
            }
        }

        var result = dateDict.map { (
            dateLabel: $0.key,
            sortDate: $0.value.date,
            cards: $0.value.cards.sorted { $0.createdAt < $1.createdAt }
        ) }

        result.sort { lhs, rhs in
            ascending ? lhs.sortDate < rhs.sortDate : lhs.sortDate > rhs.sortDate
        }

        return result.map { (dateLabel: $0.dateLabel, cards: $0.cards) }
    }

    private var cardsByColor: [(colorLabel: String, cards: [KnowledgeCard])] {
        var colorDict: [CardThemeColor: [KnowledgeCard]] = [:]
        for card in displayCards {
            let color = card.themeColor ?? .defaultTheme
            colorDict[color, default: []].append(card)
        }

        var result = colorDict.map { color, cards in
            (
                colorLabel: "\(color.displayName)色",
                sortKey: color.rawValue,
                cards: cards.sorted { $0.createdAt < $1.createdAt }
            )
        }

        result.sort { lhs, rhs in
            lhs.sortKey.localizedLowercase < rhs.sortKey.localizedLowercase
        }

        return result.map { (colorLabel: $0.colorLabel, cards: $0.cards) }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        ZDSearchField("搜索标题", text: $searchText)
    }

    // MARK: - Actions

    private func handleCardTap(_ card: KnowledgeCard) {
        if isSelectionMode {
            if selectedIDs.contains(card.id) {
                selectedIDs.remove(card.id)
            } else {
                selectedIDs.insert(card.id)
            }
        } else {
            library.recordView(for: card)
            selectedCard = card
        }
    }

    private func requestDelete(ids: Set<UUID>, title: String?) {
        guard !ids.isEmpty else {
            return
        }

        let message: String
        if let title {
            message = "删除「\(title)」后无法恢复，确认删除？"
        } else {
            message = "将删除 \(ids.count) 张卡片，删除后无法恢复，确认继续？"
        }

        deleteRequest = DeleteRequest(ids: ids, message: message)
    }
}

// MARK: - Delete Request

private struct DeleteRequest: Identifiable {
    let id = UUID()
    let ids: Set<UUID>
    let message: String
}

// MARK: - SView Tile Wrapper

private struct CardManagementSViewTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            KnowledgeCardSView(card: card)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSelectionMode {
                Circle()
                    .fill(
                        isSelected
                            ? Color.zdAccentDeep
                            : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.75)
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.zdAccentDeep.opacity(0.8), lineWidth: 1.1)
                    }
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
            }
        }
        .opacity(isSelectionMode && !isSelected ? 0.92 : 1)
    }
}

// MARK: - Card Group Section (shared between tag & date views)

private struct CardGroupSection: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore

    let title: String
    let cards: [KnowledgeCard]
    let isSelectionMode: Bool
    @Binding var selectedIDs: Set<UUID>
    let onCardTap: (KnowledgeCard) -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    private let rowSpacing: CGFloat = 10
    private let pageSpacing: CGFloat = 10

    var body: some View {
        let requiredRows: CGFloat = cards.count <= 2 ? 1.0 : 2.0
        let sectionHeight = KnowledgeCardSViewTokens.surfaceHeight * requiredRows + (requiredRows > 1 ? rowSpacing : 0)

        VStack(alignment: .leading, spacing: 12) {
            // Group title – tappable to navigate
            NavigationLink {
                FilteredCardsView(title: title, cards: cards)
                    .environmentObject(library)
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            GeometryReader { proxy in
                let pageWidth = proxy.size.width
                let pages = cards.chunked(into: 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: pageSpacing) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { _, pageCards in
                            LazyVGrid(columns: gridColumns, spacing: rowSpacing) {
                                ForEach(pageCards) { card in
                                    CardManagementSViewTile(
                                        card: card,
                                        isSelectionMode: isSelectionMode,
                                        isSelected: selectedIDs.contains(card.id)
                                    )
                                    .onTapGesture { onCardTap(card) }
                                }
                            }
                            .frame(width: pageWidth, alignment: .leading)
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .frame(height: sectionHeight)
        }
    }
}

// MARK: - Filtered Cards Sub-Page

struct FilteredCardsView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let title: String
    let cards: [KnowledgeCard]

    @State private var selectedCard: KnowledgeCard?
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var deleteRequest: DeleteRequest?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZDPageScaffold(
            title: nil,
            bottomPadding: isSelectionMode ? 98 : 12,
            contentSpacing: 14
        ) {
            headerRow
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(cards) { card in
                    CardManagementSViewTile(
                        card: card,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedIDs.contains(card.id)
                    )
                    .onTapGesture {
                        handleCardTap(card)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode {
                selectionToolbar
            }
        }
        .sheet(item: $selectedCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .alert(
            "确认删除",
            isPresented: showDeleteAlert,
            presenting: deleteRequest
        ) { request in
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                library.deleteCards(ids: request.ids)
                selectedIDs.subtract(request.ids)
            }
        } message: { request in
            Text(request.message)
        }
    }

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { deleteRequest != nil },
            set: { if !$0 { deleteRequest = nil } }
        )
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            ZDIconButton(
                systemName: isSelectionMode ? "xmark" : "checkmark.circle",
                active: isSelectionMode
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedIDs.removeAll()
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var selectionToolbar: some View {
        let actionButtonWidth: CGFloat = 96
        let allSelected = !cards.isEmpty && selectedIDs.count == cards.count

        return ZDFloatingActionBar {
            ZDSecondaryButton(text: allSelected ? "取消全选" : "全选", fullWidth: false) {
                let visibleIDs = Set(cards.map(\.id))
                if !visibleIDs.isEmpty && selectedIDs == visibleIDs {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = visibleIDs
                }
            }
            .frame(width: actionButtonWidth)

            Text("已选 \(selectedIDs.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            ZDPrimaryButton(text: "删除", isDisabled: selectedIDs.isEmpty, fullWidth: false) {
                requestDelete(ids: selectedIDs)
            }
            .frame(width: actionButtonWidth)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func handleCardTap(_ card: KnowledgeCard) {
        if isSelectionMode {
            if selectedIDs.contains(card.id) {
                selectedIDs.remove(card.id)
            } else {
                selectedIDs.insert(card.id)
            }
        } else {
            library.recordView(for: card)
            selectedCard = card
        }
    }

    private func requestDelete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        deleteRequest = DeleteRequest(
            ids: ids,
            message: "将删除 \(ids.count) 张卡片，删除后无法恢复，确认继续？"
        )
    }
}

// MARK: - Array Chunking Helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Card Tile

struct CardTitleTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard
    let isSelectionMode: Bool
    let isSelected: Bool

    private var theme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    private var useLightCardText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    private var titleColor: Color {
        useLightCardText ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private var chipTextColor: Color {
        useLightCardText ? Color.white.opacity(0.9) : theme.primaryColor.opacity(0.9)
    }

    private var chipBackgroundColor: Color {
        if useLightCardText {
            return Color.white.opacity(0.18)
        }
        return Color.white.opacity(colorScheme == .dark ? 0.1 : 0.46)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text(card.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 10)

                if let tags = card.tags, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(chipTextColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(chipBackgroundColor)
                                .clipShape(Capsule())
                        }
                        if tags.count > 2 {
                            Text("+\(tags.count - 2)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(useLightCardText ? Color.white.opacity(0.76) : .secondary)
                        }
                    }
                    .lineLimit(1)
                } else {
                    Text("知识卡片")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(chipTextColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(chipBackgroundColor)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .padding(.trailing, 16)

            if isSelectionMode {
                Circle()
                    .fill(isSelected ? Color.zdAccentDeep : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.75))
                    .overlay {
                        Circle()
                            .stroke(Color.zdAccentDeep.opacity(0.8), lineWidth: 1.1)
                    }
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .zdPunchedGlassBackground(
            theme.cardBackgroundGradient,
            metrics: ZDPunchedCardMetrics(cornerRadius: 14),
            borderGradient: theme.cardBorderGradient
        )
        .shadow(color: theme.primaryColor.opacity(0.14), radius: 8, x: 0, y: 4)
        .opacity(isSelectionMode && !isSelected ? 0.92 : 1)
    }
}

#Preview("Card Management") {
    CardManagementView()
        .environmentObject(KnowledgeCardLibraryStore())
        .environmentObject(KnowledgeGraphStore())
}
