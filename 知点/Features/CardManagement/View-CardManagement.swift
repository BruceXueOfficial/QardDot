import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Sort Mode

enum CardSortMode: Equatable, RawRepresentable {
    case defaultSort
    case byTag(ascending: Bool)
    case byTagFolder
    case byDate(ascending: Bool)
    case byColor

    var rawValue: String {
        switch self {
        case .defaultSort: return "defaultSort"
        case .byTag(let asc): return "byTag:\(asc)"
        case .byTagFolder: return "byTagFolder"
        case .byDate(let asc): return "byDate:\(asc)"
        case .byColor: return "byColor"
        }
    }

    init?(rawValue: String) {
        if rawValue == "defaultSort" { self = .defaultSort }
        else if rawValue.hasPrefix("byTag:") {
            self = .byTag(ascending: rawValue.hasSuffix("true"))
        }
        else if rawValue == "byTagFolder" { self = .byTagFolder }
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
    @State private var selectedFolderTags: Set<String> = []
    @State private var deleteRequest: DeleteRequest?
    @State private var tagFolderDeleteRequest: TagFolderDeleteRequest?
    @State private var showBatchTagEditor = false
    @State private var showBatchColorEditor = false
    @State private var showBatchTagFolderColorEditor = false

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
                selectedFolderTags.removeAll()
                deleteRequest = nil
                tagFolderDeleteRequest = nil
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
        .sheet(isPresented: $showBatchTagEditor) {
            let selectedCards = displayCards.filter { selectedIDs.contains($0.id) }
            CardManagementBatchTagEditorScreen(
                cards: selectedCards,
                existingTags: library.allUniqueTags()
            ) { finalSelectedIDs, updatedTags in
                // Find all cards whose selection was preserved
                let remainingCards = displayCards.filter { finalSelectedIDs.contains($0.id) }
                for card in remainingCards {
                    var modifiedCard = card
                    modifiedCard.tags = updatedTags.isEmpty ? nil : updatedTags
                    modifiedCard.touchUpdatedAt()
                    library.updateCard(modifiedCard)
                }
                
                // Clear selection after batch action
                selectedIDs.removeAll()
            }
            .environmentObject(library)
        }
        .sheet(isPresented: $showBatchColorEditor) {
            let selectedCards = displayCards.filter { selectedIDs.contains($0.id) }
            CardManagementBatchColorEditorScreen(cards: selectedCards) { finalSelectedIDs, color in
                library.updateCardsThemeColor(ids: finalSelectedIDs, color: color)
                selectedIDs.removeAll()
            }
        }
        .sheet(isPresented: $showBatchTagFolderColorEditor) {
            let selectedFolders = tagFolderGroups
                .filter { selectedFolderTags.contains($0.tag) }
                .map {
                    CardManagementBatchTagFolderItem(
                        tag: $0.tag,
                        model: $0.model,
                        currentTheme: $0.theme
                    )
                }
            CardManagementBatchTagFolderColorEditorScreen(folders: selectedFolders) { finalSelectedTags, color in
                library.updateTagColors(tags: finalSelectedTags, color: color)
                selectedFolderTags.removeAll()
            }
        }
    }

    private var cardsWarehousePage: some View {
        ZDFixedHeaderPageScaffold(
            bottomPadding: isSelectionMode ? 98 : 12,
            headerSpacing: 14,
            contentSpacing: 14
        ) {
            headerRow
            searchBar
        } content: {

            switch sortMode {
            case .defaultSort:
                defaultGridView
            case .byTag:
                tagGroupedView
            case .byTagFolder:
                tagFolderGroupedView
            case .byDate:
                dateGroupedView
            case .byColor:
                colorGroupedView
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode {
                if sortMode == .byTagFolder {
                    tagFolderSelectionToolbar
                } else {
                    selectionToolbar
                }
            }
        }
        .environment(\.zdListRenderScope, .warehouse)
        .onChange(of: displayCards.map(\.id)) { _, ids in
            selectedIDs.formIntersection(Set(ids))
        }
        .onChange(of: tagFolderGroups.map(\.tag)) { _, tags in
            selectedFolderTags.formIntersection(Set(tags))
        }
        .onChange(of: sortMode) { oldMode, newMode in
            let oldIsFolderMode: Bool
            if case .byTagFolder = oldMode {
                oldIsFolderMode = true
            } else {
                oldIsFolderMode = false
            }

            let newIsFolderMode: Bool
            if case .byTagFolder = newMode {
                newIsFolderMode = true
            } else {
                newIsFolderMode = false
            }

            guard oldIsFolderMode != newIsFolderMode else {
                return
            }

            selectedIDs.removeAll()
            selectedFolderTags.removeAll()
            deleteRequest = nil
            tagFolderDeleteRequest = nil
        }
        .background {
            ZDKeyboardDismissOnOutsideTap()
        }
        .confirmationDialog(
            "删除标签文件夹",
            isPresented: showTagFolderDeleteDialog,
            titleVisibility: .visible
        ) {
            if let request = tagFolderDeleteRequest {
                Button("仅删除卡片标签") {
                    library.removeTagsFromCards(tags: request.tags)
                    selectedFolderTags.removeAll()
                }

                Button("删除标签和卡片", role: .destructive) {
                    library.deleteCardsMatchingAnyTags(request.tags)
                    selectedFolderTags.removeAll()
                }
            }

            Button("取消", role: .cancel) {
                tagFolderDeleteRequest = nil
            }
        } message: {
            if let request = tagFolderDeleteRequest {
                Text(request.message)
            }
        }
    }

    private var graphWarehousePage: some View {
        ZDFixedHeaderPageScaffold(
            bottomPadding: 16,
            headerSpacing: 14,
            contentSpacing: 14
        ) {
            headerRow
        } content: {
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
                    sortMode = .byTagFolder
                }
            } label: {
                Label("按标签分组", systemImage: sortMode == .byTagFolder ? "checkmark" : "folder")
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
                .foregroundStyle(sortMode == .defaultSort ? Color.primary.opacity(0.85) : Color.white)
                .frame(width: 36, height: 36)
                .background(
                    sortMode == .defaultSort
                        ? Color.clear
                        : Color.zdAccentDeep
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
                    selectedFolderTags.removeAll()
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

    // MARK: - Tag Folder Grouped View

    private var tagFolderGroupedView: some View {
        let groups = tagFolderGroups
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(groups) { group in
                if isSelectionMode {
                    TagFolderManagementSViewTile(
                        group: group,
                        isSelectionMode: true,
                        isSelected: selectedFolderTags.contains(group.tag)
                    )
                    .onTapGesture {
                        handleTagFolderTap(group)
                    }
                } else {
                    NavigationLink {
                        TagFolderDetailCardsView(
                            title: group.tag,
                            originalCards: group.cards,
                            folderModel: group.model
                        )
                        .environmentObject(library)
                        .environmentObject(graphStore)
                    } label: {
                        TagFolderManagementSViewTile(
                            group: group,
                            isSelectionMode: false,
                            isSelected: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tagFolderGroups: [TagFolderGroup] {
        cardsByTag.map { group in
            TagFolderGroup(
                tag: group.tag,
                cards: group.cards,
                model: convertToTagFolderModel(tag: group.tag, cards: group.cards),
                theme: library.tagColor(for: group.tag)
            )
        }
    }

    private func convertToTagFolderModel(tag: String, cards: [KnowledgeCard]) -> ZDTagCollectionFolderModel {
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
        let allSelected = !displayCards.isEmpty && selectedIDs.count == displayCards.count
        let hasSelection = !selectedIDs.isEmpty

        return ZDSelectionActionBar(selectionText: "已选 \(selectedIDs.count)") {
            Button {
                let visibleIDs = Set(displayCards.map(\.id))
                if !visibleIDs.isEmpty && selectedIDs == visibleIDs {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = visibleIDs
                }
            } label: {
                ZDActionBarButtonLabel(
                    title: allSelected ? "取消" : "全选",
                    tone: allSelected ? .destructive : .primary
                )
            }
            .buttonStyle(.plain)
        } trailing: {
            Menu {
                Button(role: .destructive) {
                    requestDelete(ids: selectedIDs, title: nil)
                } label: {
                    ZDDestructiveMenuLabel(title: "删除卡片")
                }

                Button {
                    showBatchTagEditor = true
                } label: {
                    Label("编辑标签", systemImage: "tag")
                }

                Button {
                    showBatchColorEditor = true
                } label: {
                    Label("编辑颜色", systemImage: "paintpalette")
                }
            } label: {
                ZDActionBarButtonLabel(title: "编辑", isEnabled: hasSelection)
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var tagFolderSelectionToolbar: some View {
        let visibleTags = Set(tagFolderGroups.map(\.tag))
        let allSelected = !visibleTags.isEmpty && selectedFolderTags == visibleTags
        let hasSelection = !selectedFolderTags.isEmpty

        return ZDSelectionActionBar(selectionText: "已选 \(selectedFolderTags.count)") {
            Button {
                if !visibleTags.isEmpty && selectedFolderTags == visibleTags {
                    selectedFolderTags.removeAll()
                } else {
                    selectedFolderTags = visibleTags
                }
            } label: {
                ZDActionBarButtonLabel(
                    title: allSelected ? "取消" : "全选",
                    tone: allSelected ? .destructive : .primary
                )
            }
            .buttonStyle(.plain)
        } trailing: {
            Menu {
                Button(role: .destructive) {
                    requestTagFolderDelete(tags: selectedFolderTags)
                } label: {
                    ZDDestructiveMenuLabel(title: "删除文件夹")
                }

                Button {
                    showBatchTagFolderColorEditor = true
                } label: {
                    Label("编辑颜色", systemImage: "paintpalette")
                }
            } label: {
                ZDActionBarButtonLabel(title: "编辑", isEnabled: hasSelection)
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection)
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

    private func handleTagFolderTap(_ group: TagFolderGroup) {
        guard isSelectionMode else {
            return
        }

        if selectedFolderTags.contains(group.tag) {
            selectedFolderTags.remove(group.tag)
        } else {
            selectedFolderTags.insert(group.tag)
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

    private func requestTagFolderDelete(tags: Set<String>) {
        guard !tags.isEmpty else {
            return
        }

        let message: String
        if tags.count == 1, let tag = tags.first {
            message = "你可以仅删除「\(tag)」这个标签在卡片上的绑定关系，或直接删除该标签以及其下的所有卡片。"
        } else {
            message = "已选择 \(tags.count) 个标签文件夹。你可以仅删除这些标签在卡片上的绑定关系，或直接删除这些标签以及其下的所有卡片。"
        }

        tagFolderDeleteRequest = TagFolderDeleteRequest(tags: tags, message: message)
    }

    private var showTagFolderDeleteDialog: Binding<Bool> {
        Binding(
            get: { tagFolderDeleteRequest != nil },
            set: { presented in
                if !presented {
                    tagFolderDeleteRequest = nil
                }
            }
        )
    }
}

// MARK: - Delete Request

private struct DeleteRequest: Identifiable {
    let id = UUID()
    let ids: Set<UUID>
    let message: String
}

private struct TagFolderDeleteRequest: Identifiable {
    let id = UUID()
    let tags: Set<String>
    let message: String
}

private struct TagFolderGroup: Identifiable {
    let tag: String
    let cards: [KnowledgeCard]
    let model: ZDTagCollectionFolderModel
    let theme: CardThemeColor

    var id: String { tag }
}

// MARK: - SView Tile Wrapper

private struct CardManagementSViewTile: View {
    let card: KnowledgeCard
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        KnowledgeCardSView(card: card, hidesTrailingMeta: isSelectionMode)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                if isSelectionMode {
                    selectionIndicator
                        .padding(.bottom, 8)
                        .padding(.trailing, 8)
                }
            }
            .overlay {
                if isSelectionMode {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? Color.red.opacity(0.9)
                                : Color.primary.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            }
            .scaleEffect(isSelectionMode && isSelected ? 0.98 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.85), value: isSelected)
    }

    private var selectionIndicator: some View {
        Circle()
            .fill(Color(uiColor: .systemBackground))
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.red : Color.secondary.opacity(0.45), lineWidth: 1.2)
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

private struct TagFolderManagementSViewTile: View {
    let group: TagFolderGroup
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        ZDTagCollectionFolderSView(
            model: group.model,
            theme: group.theme
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            if isSelectionMode {
                selectionIndicator
                    .padding(.bottom, 8)
                    .padding(.trailing, 8)
            }
        }
        .overlay {
            if isSelectionMode {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.red.opacity(0.9)
                            : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .scaleEffect(isSelectionMode && isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.85), value: isSelected)
    }

    private var selectionIndicator: some View {
        Circle()
            .fill(Color(uiColor: .systemBackground))
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.red : Color.secondary.opacity(0.45), lineWidth: 1.2)
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
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
    @State private var showBatchTagEditor = false
    @State private var showBatchColorEditor = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZDFixedHeaderPageScaffold(
            bottomPadding: isSelectionMode ? 98 : 12,
            headerSpacing: 14,
            contentSpacing: 14
        ) {
            headerRow
        } content: {
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
        .sheet(isPresented: $showBatchTagEditor) {
            let selectedCards = cards.filter { selectedIDs.contains($0.id) }
            CardManagementBatchTagEditorScreen(
                cards: selectedCards,
                existingTags: library.allUniqueTags()
            ) { finalSelectedIDs, updatedTags in
                // Find all cards whose selection was preserved
                let remainingCards = cards.filter { finalSelectedIDs.contains($0.id) }
                for card in remainingCards {
                    var modifiedCard = card
                    modifiedCard.tags = updatedTags.isEmpty ? nil : updatedTags
                    modifiedCard.touchUpdatedAt()
                    library.updateCard(modifiedCard)
                }
                
                // Clear selection after batch action
                selectedIDs.removeAll()
            }
            .environmentObject(library)
        }
        .sheet(isPresented: $showBatchColorEditor) {
            let selectedCards = cards.filter { selectedIDs.contains($0.id) }
            CardManagementBatchColorEditorScreen(cards: selectedCards) { finalSelectedIDs, color in
                library.updateCardsThemeColor(ids: finalSelectedIDs, color: color)
                selectedIDs.removeAll()
            }
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
        let allSelected = !cards.isEmpty && selectedIDs.count == cards.count
        let hasSelection = !selectedIDs.isEmpty

        return ZDSelectionActionBar(selectionText: "已选 \(selectedIDs.count)") {
            Button {
                let visibleIDs = Set(cards.map(\.id))
                if !visibleIDs.isEmpty && selectedIDs == visibleIDs {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = visibleIDs
                }
            } label: {
                ZDActionBarButtonLabel(
                    title: allSelected ? "取消全选" : "全选",
                    tone: allSelected ? .destructive : .primary
                )
            }
            .buttonStyle(.plain)
        } trailing: {
            Menu {
                Button(role: .destructive) {
                    requestDelete(ids: selectedIDs)
                } label: {
                    ZDDestructiveMenuLabel(title: "删除卡片")
                }

                Button {
                    showBatchTagEditor = true
                } label: {
                    Label("编辑标签", systemImage: "tag")
                }

                Button {
                    showBatchColorEditor = true
                } label: {
                    Label("编辑颜色", systemImage: "paintpalette")
                }
            } label: {
                ZDActionBarButtonLabel(title: "编辑", isEnabled: hasSelection)
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection)
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

// MARK: - Tag Folder Detail Sub-Page

struct TagFolderDetailCardsView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let title: String
    let originalCards: [KnowledgeCard]
    let folderModel: ZDTagCollectionFolderModel

    @State private var selectedCard: KnowledgeCard?
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var deleteRequest: DeleteRequest?
    @State private var showBatchTagEditor = false
    @State private var showBatchColorEditor = false
    @State private var showThemePicker = false

    enum LocalSortMode: Equatable {
        case defaultSort
        case byDate(ascending: Bool)
        case byColor
    }
    @State private var localSortMode: LocalSortMode = .defaultSort

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZDFixedHeaderPageScaffold(
            bottomPadding: isSelectionMode ? 98 : 12,
            headerSpacing: 14,
            contentSpacing: 14
        ) {
            headerRow
        } content: {
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
        .sheet(isPresented: $showThemePicker) {
            TagFolderThemeColorPicker(
                tagFolderModel: folderModel,
                currentTheme: library.tagColor(for: title),
                onThemeSelected: { color in
                    library.updateTagColor(tag: title, color: color)
                }
            )
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
        .sheet(isPresented: $showBatchTagEditor) {
            let selectedCards = displayCards.filter { selectedIDs.contains($0.id) }
            CardManagementBatchTagEditorScreen(
                cards: selectedCards,
                existingTags: library.allUniqueTags()
            ) { finalSelectedIDs, updatedTags in
                // Find all cards whose selection was preserved
                let remainingCards = displayCards.filter { finalSelectedIDs.contains($0.id) }
                for card in remainingCards {
                    var modifiedCard = card
                    modifiedCard.tags = updatedTags.isEmpty ? nil : updatedTags
                    modifiedCard.touchUpdatedAt()
                    library.updateCard(modifiedCard)
                }
                
                // Clear selection after batch action
                selectedIDs.removeAll()
            }
            .environmentObject(library)
        }
        .sheet(isPresented: $showBatchColorEditor) {
            let selectedCards = displayCards.filter { selectedIDs.contains($0.id) }
            CardManagementBatchColorEditorScreen(cards: selectedCards) { finalSelectedIDs, color in
                library.updateCardsThemeColor(ids: finalSelectedIDs, color: color)
                selectedIDs.removeAll()
            }
        }
    }

    private var displayCards: [KnowledgeCard] {
        var list = originalCards
        switch localSortMode {
        case .defaultSort:
            list.sort { $0.createdAt > $1.createdAt }
        case .byDate(let asc):
            list.sort { asc ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .byColor:
            list.sort { 
                let c1 = $0.themeColor?.rawValue ?? ""
                let c2 = $1.themeColor?.rawValue ?? ""
                return c1.localizedLowercase < c2.localizedLowercase 
            }
        }
        return list
    }

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { deleteRequest != nil },
            set: { if !$0 { deleteRequest = nil } }
        )
    }

    private var sortMenuButton: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    localSortMode = .defaultSort
                }
            } label: {
                Label("默认排列", systemImage: localSortMode == .defaultSort ? "checkmark" : "")
            }

            Menu {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        localSortMode = .byDate(ascending: true)
                    }
                } label: {
                    Label("升序排列", systemImage: localSortMode == .byDate(ascending: true) ? "checkmark" : "")
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        localSortMode = .byDate(ascending: false)
                    }
                } label: {
                    Label("降序排列", systemImage: localSortMode == .byDate(ascending: false) ? "checkmark" : "")
                }
            } label: {
                Label("按照时间", systemImage: "clock")
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    localSortMode = .byColor
                }
            } label: {
                Label("按照颜色", systemImage: localSortMode == .byColor ? "checkmark" : "paintpalette")
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(localSortMode == .defaultSort ? Color.primary.opacity(0.85) : Color.white)
                .frame(width: 36, height: 36)
                .background(
                    localSortMode == .defaultSort
                        ? Color.clear
                        : Color.zdAccentDeep
                )
                .zdInteractiveControlStyle(cornerRadius: 999)
        }
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

            HStack(spacing: 8) {
                sortMenuButton
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
                ZDIconButton(
                    systemName: "paintpalette",
                    active: showThemePicker
                ) {
                    showThemePicker = true
                }
            }
        }
        .padding(.top, 4)
    }

    private var selectionToolbar: some View {
        let allSelected = !displayCards.isEmpty && selectedIDs.count == displayCards.count
        let hasSelection = !selectedIDs.isEmpty

        return ZDSelectionActionBar(selectionText: "已选 \(selectedIDs.count)") {
            Button {
                let visibleIDs = Set(displayCards.map(\.id))
                if !visibleIDs.isEmpty && selectedIDs == visibleIDs {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = visibleIDs
                }
            } label: {
                ZDActionBarButtonLabel(
                    title: allSelected ? "取消全选" : "全选",
                    tone: allSelected ? .destructive : .primary
                )
            }
            .buttonStyle(.plain)
        } trailing: {
            Menu {
                Button(role: .destructive) {
                    requestDelete(ids: selectedIDs)
                } label: {
                    ZDDestructiveMenuLabel(title: "删除卡片")
                }

                Button {
                    showBatchTagEditor = true
                } label: {
                    Label("编辑标签", systemImage: "tag")
                }

                Button {
                    showBatchColorEditor = true
                } label: {
                    Label("编辑颜色", systemImage: "paintpalette")
                }
            } label: {
                ZDActionBarButtonLabel(title: "编辑", isEnabled: hasSelection)
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection)
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

#Preview("Card Management") {
    CardManagementView()
        .environmentObject(KnowledgeCardLibraryStore())
        .environmentObject(KnowledgeGraphStore())
}

#if canImport(UIKit)
private struct ZDKeyboardDismissOnOutsideTap: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(to: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: UIView?

        private lazy var tapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func attachIfNeeded(to anchorView: UIView) {
            let targetView = rootContainer(for: anchorView)
            guard hostView !== targetView else { return }
            detach()
            hostView = targetView
            targetView.addGestureRecognizer(tapRecognizer)
        }

        func detach() {
            hostView?.removeGestureRecognizer(tapRecognizer)
            hostView = nil
        }

        @objc
        private func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !isTextInputView(touch.view)
        }

        private func rootContainer(for view: UIView) -> UIView {
            var current = view
            while let superview = current.superview, !(superview is UIWindow) {
                current = superview
            }
            return current
        }

        private func isTextInputView(_ view: UIView?) -> Bool {
            var current = view
            while let candidate = current {
                if candidate is UITextField || candidate is UITextView || candidate is UISearchBar {
                    return true
                }
                current = candidate.superview
            }
            return false
        }
    }
}
#endif
