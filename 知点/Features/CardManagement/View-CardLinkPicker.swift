import SwiftUI

// MARK: - Card Link Picker Sheet

struct CardLinkPickerSheet: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// IDs of cards that should be excluded from the picker (e.g. the card being edited itself).
    var excludedCardIDs: Set<UUID> = []

    /// Callback with the set of selected card IDs when the user confirms.
    let onLink: (Set<UUID>) -> Void

    @State private var searchText = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var sortMode: CardSortMode = .defaultSort

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerRow
                        searchBar
                        cardGrid
                    }
                    .padding(.top, ZDMainPageLayout.contentTopInset)
                    .padding(.horizontal, ZDSpacingScale.default.pageHorizontal)
                    .padding(.bottom, 98)
                }
                .zdPageBackground()
                .zdTopScrollBlurFade()
                .toolbar(.hidden, for: .navigationBar)

                bottomBar
            }
        }
        .environment(\.zdListRenderScope, .warehouse)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("关联卡片")
                .font(ZDTypographyScale.default.pageTitle)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                sortMenuButton
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Sort Menu

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

    // MARK: - Search

    private var searchBar: some View {
        ZDSearchField("搜索标题", text: $searchText)
    }

    // MARK: - Card Grid

    @ViewBuilder
    private var cardGrid: some View {
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

    private var defaultGridView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayCards) { card in
                cardTile(card)
            }
        }
    }

    private var tagGroupedView: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(cardsByTag, id: \.tag) { group in
                linkPickerGroupSection(title: group.tag, cards: group.cards)
            }
        }
    }

    private var dateGroupedView: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(cardsByDate, id: \.dateLabel) { group in
                linkPickerGroupSection(title: group.dateLabel, cards: group.cards)
            }
        }
    }

    private var colorGroupedView: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(cardsByColor, id: \.colorLabel) { group in
                linkPickerGroupSection(title: group.colorLabel, cards: group.cards)
            }
        }
    }

    private func linkPickerGroupSection(title: String, cards: [KnowledgeCard]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(cards) { card in
                    cardTile(card)
                }
            }
        }
    }

    // MARK: - Card Tile

    private func cardTile(_ card: KnowledgeCard) -> some View {
        let isSelected = selectedIDs.contains(card.id)

        return ZStack(alignment: .bottomTrailing) {
            KnowledgeCardSView(card: card)
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .opacity(isSelected ? 1 : 0.92)
        .onTapGesture {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                if isSelected {
                    selectedIDs.remove(card.id)
                } else {
                    selectedIDs.insert(card.id)
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        let actionButtonWidth: CGFloat = 96

        return ZDFloatingActionBar {
            ZDSecondaryButton(text: "取消", fullWidth: false) {
                dismiss()
            }
            .frame(width: actionButtonWidth, alignment: .leading)

            Text("已选卡片 \(selectedIDs.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            ZDPrimaryButton(text: "关联", isDisabled: selectedIDs.isEmpty, fullWidth: false) {
                onLink(selectedIDs)
                dismiss()
            }
            .frame(width: actionButtonWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Data

    private var displayCards: [KnowledgeCard] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = library.cards
            .filter { !excludedCardIDs.contains($0.id) }

        if keyword.isEmpty {
            return base.sorted { $0.createdAt > $1.createdAt }
        } else {
            return base
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

        var result = tagDict.map { (tag: $0.key, cards: $0.value.sorted { $0.createdAt < $1.createdAt }) }
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
}

// MARK: - Preview

#Preview("Card Link Picker") {
    CardLinkPickerSheet { selectedIDs in
        print("Linked cards: \(selectedIDs)")
    }
    .environmentObject(KnowledgeCardLibraryStore())
}
