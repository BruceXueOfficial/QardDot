import SwiftUI

struct GraphCardPickerSheet: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.dismiss) private var dismiss

    let title: String
    let excludedCardIDs: Set<UUID>
    let onSelect: (KnowledgeCard) -> Void

    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: nil, bottomPadding: 18, contentSpacing: 12) {
                header
                ZDSearchField("搜索标题", text: $searchText)

                if filteredCards.isEmpty {
                    ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                        Text("没有可添加的卡片")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredCards) { card in
                            Button {
                                onSelect(card)
                                dismiss()
                            } label: {
                                CardTitleTile(
                                    card: card,
                                    isSelectionMode: false,
                                    isSelected: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 10)

            Button("取消") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var filteredCards: [KnowledgeCard] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let base = library.cards
            .filter { !excludedCardIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        guard !keyword.isEmpty else {
            return base
        }

        return base.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
            || ($0.tags ?? []).contains(where: { $0.localizedCaseInsensitiveContains(keyword) })
        }
    }
}
