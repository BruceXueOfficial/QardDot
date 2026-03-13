import SwiftUI

struct CardManagementBatchColorEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let cards: [KnowledgeCard]
    let onConfirm: (Set<UUID>, CardThemeColor) -> Void

    @State private var activeCardIDs: Set<UUID>
    @State private var selectedColor: CardThemeColor

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    init(
        cards: [KnowledgeCard],
        onConfirm: @escaping (Set<UUID>, CardThemeColor) -> Void
    ) {
        self.cards = cards
        self.onConfirm = onConfirm

        let initialColor = cards.first?.themeColor ?? .defaultTheme
        _activeCardIDs = State(initialValue: Set(cards.map(\.id)))
        _selectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    cardsCarousel
                        .padding(.top, 8)

                    statusIndicatorRow

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CardThemeColor.allCases) { color in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    selectedColor = color
                                }
                            } label: {
                                colorCircle(color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
                .padding(.top, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("自定义样式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(selectedColor.primaryColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onConfirm(activeCardIDs, selectedColor)
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedColor.primaryColor)
                    .disabled(activeCardIDs.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var cardsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(cards) { card in
                    HStack {
                        Spacer(minLength: 0)
                        previewCard(for: card)
                        Spacer(minLength: 0)
                    }
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func previewCard(for card: KnowledgeCard) -> some View {
        let isActive = activeCardIDs.contains(card.id)
        let previewCard = cardPreview(for: card, isActive: isActive)

        return KnowledgeCardSView(card: previewCard)
            .frame(width: 170)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        toggleCardActive(card.id)
                    }
                } label: {
                    Circle()
                        .fill(
                            isActive
                                ? selectedColor.primaryColor
                                : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.82)
                        )
                        .overlay {
                            Circle()
                                .stroke(selectedColor.primaryColor.opacity(0.82), lineWidth: 1.2)
                        }
                        .overlay {
                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .opacity(isActive ? 1.0 : 0.56)
    }

    private var statusIndicatorRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selectedColor.primaryColor)

            Text("已选中 \(activeCardIDs.count) 张卡片，支持向左滑动查看")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func colorCircle(_ color: CardThemeColor) -> some View {
        let isSelected = selectedColor == color

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.cardBackgroundStyle)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(color.cardBorderGradient, lineWidth: isSelected ? 3 : 1.2)
                    )
                    .shadow(color: color.primaryColor.opacity(0.35), radius: 6, x: 0, y: 3)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(color.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func cardPreview(for card: KnowledgeCard, isActive: Bool) -> KnowledgeCard {
        guard isActive else {
            return card
        }

        var updatedCard = card
        updatedCard.themeColor = selectedColor
        return updatedCard
    }

    private func toggleCardActive(_ id: UUID) {
        if activeCardIDs.contains(id) {
            activeCardIDs.remove(id)
        } else {
            activeCardIDs.insert(id)
        }
    }
}

struct CardManagementBatchTagFolderItem: Identifiable {
    let tag: String
    let model: ZDTagCollectionFolderModel
    let currentTheme: CardThemeColor

    var id: String { tag }
}

struct CardManagementBatchTagFolderColorEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let folders: [CardManagementBatchTagFolderItem]
    let onConfirm: (Set<String>, CardThemeColor) -> Void

    @State private var activeTags: Set<String>
    @State private var selectedColor: CardThemeColor

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    init(
        folders: [CardManagementBatchTagFolderItem],
        onConfirm: @escaping (Set<String>, CardThemeColor) -> Void
    ) {
        self.folders = folders
        self.onConfirm = onConfirm

        let initialColor = folders.first?.currentTheme ?? .defaultTheme
        _activeTags = State(initialValue: Set(folders.map(\.tag)))
        _selectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    foldersCarousel
                        .padding(.top, 8)

                    statusIndicatorRow

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CardThemeColor.allCases) { color in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    selectedColor = color
                                }
                            } label: {
                                colorCircle(color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
                .padding(.top, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("标签样式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(selectedColor.primaryColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onConfirm(activeTags, selectedColor)
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedColor.primaryColor)
                    .disabled(activeTags.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var foldersCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(folders) { folder in
                    HStack {
                        Spacer(minLength: 0)
                        previewFolder(for: folder)
                        Spacer(minLength: 0)
                    }
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func previewFolder(for folder: CardManagementBatchTagFolderItem) -> some View {
        let isActive = activeTags.contains(folder.tag)
        let theme = isActive ? selectedColor : folder.currentTheme

        return ZDTagCollectionFolderSView(
            model: folder.model,
            theme: theme
        )
        .frame(width: 170)
        .overlay(alignment: .bottomTrailing) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    toggleFolderActive(folder.tag)
                }
            } label: {
                Circle()
                    .fill(
                        isActive
                            ? selectedColor.primaryColor
                            : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.82)
                    )
                    .overlay {
                        Circle()
                            .stroke(selectedColor.primaryColor.opacity(0.82), lineWidth: 1.2)
                    }
                    .overlay {
                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
        .opacity(isActive ? 1.0 : 0.56)
    }

    private var statusIndicatorRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selectedColor.primaryColor)

            Text("已选中 \(activeTags.count) 个文件夹，支持向左滑动查看")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func colorCircle(_ color: CardThemeColor) -> some View {
        let isSelected = selectedColor == color

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.cardBackgroundStyle)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(color.cardBorderGradient, lineWidth: isSelected ? 3 : 1.2)
                    )
                    .shadow(color: color.primaryColor.opacity(0.35), radius: 6, x: 0, y: 3)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(color.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleFolderActive(_ tag: String) {
        if activeTags.contains(tag) {
            activeTags.remove(tag)
        } else {
            activeTags.insert(tag)
        }
    }
}

#Preview("Batch Color Editor") {
    CardManagementBatchColorEditorScreen(
        cards: [
            KnowledgeCard.previewShort,
            {
                var card = KnowledgeCard.previewShort
                card.title = "第二张卡片"
                card.themeColor = .green
                return card
            }()
        ],
        onConfirm: { _, _ in }
    )
}

#Preview("Batch Tag Folder Color Editor") {
    CardManagementBatchTagFolderColorEditorScreen(
        folders: [
            CardManagementBatchTagFolderItem(
                tag: "Git",
                model: .demo,
                currentTheme: .blue
            ),
            CardManagementBatchTagFolderItem(
                tag: "健康",
                model: .init(
                    tagName: "健康",
                    cardCount: 4,
                    textModuleCount: 10,
                    imageModuleCount: 1,
                    codeModuleCount: 0,
                    linkModuleCount: 2,
                    formulaModuleCount: 0,
                    addedDateText: "Mar 10, 2026",
                    viewCount: 16
                ),
                currentTheme: .green
            )
        ],
        onConfirm: { _, _ in }
    )
}
