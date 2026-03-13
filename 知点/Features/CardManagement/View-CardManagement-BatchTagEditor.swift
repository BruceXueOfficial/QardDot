import SwiftUI

struct CardManagementBatchTagEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let cards: [KnowledgeCard]
    let existingTags: [String]
    let onConfirm: (Set<UUID>, [String]) -> Void // Returns the UUIDs of the cards that remained selected, and the new array of tags

    @State private var tagInput = ""
    @State private var selectedTags: [String] = []
    @State private var activeCardIDs: Set<UUID>

    init(
        cards: [KnowledgeCard],
        existingTags: [String],
        onConfirm: @escaping (Set<UUID>, [String]) -> Void
    ) {
        self.cards = cards
        self.existingTags = existingTags
        self.onConfirm = onConfirm
        _activeCardIDs = State(initialValue: Set(cards.map(\.id)))
    }

    private var theme: CardThemeColor {
        cards.first?.themeColor ?? .defaultTheme
    }

    private var useLightPreviewText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    private var selectedTagKeys: Set<String> {
        Set(selectedTags.map { $0.lowercased() })
    }

    private var availableExistingTags: [String] {
        existingTags.filter { tag in
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                return false
            }
            return !selectedTagKeys.contains(normalized.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cardsCarousel

                    statusIndicatorRow

                    tagEditorSection

                    existingTagSection
                }
                .padding(.vertical, 20)
            }
            .zdPageBackground()
            .navigationTitle("批量编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        confirmImport()
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryColor)
                    .disabled(activeCardIDs.isEmpty)
                }
            }
            .tint(theme.primaryColor)
        }
    }

    private var cardsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(cards) { card in
                    previewCard(for: card)
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
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(card.title)
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(theme.prefersLightForeground(in: colorScheme) ? Color.white.opacity(0.95) : .primary)
                .lineLimit(3)

            HStack(alignment: .center, spacing: 8) {
                Group {
                    if selectedTags.isEmpty {
                        Text("点击下方输入或从已有标签中添加")
                            .font(.caption)
                            .foregroundStyle(theme.prefersLightForeground(in: colorScheme) ? Color.white.opacity(0.82) : .secondary)
                    } else {
                        selectedTagRow
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    toggleCardActive(card.id)
                } label: {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(theme.prefersLightForeground(in: colorScheme) ? Color.white : theme.primaryColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zdPunchedGlassBackground(
            card.themeColor?.cardBackgroundGradient ?? theme.cardBackgroundGradient,
            metrics: ZDPunchedCardMetrics(cornerRadius: 24, holeScale: 1.0),
            borderGradient: card.themeColor?.cardBorderGradient ?? theme.cardBorderGradient
        )
        .opacity(isActive ? 1.0 : 0.6)
    }

    private var statusIndicatorRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
            Text("已选中 \(activeCardIDs.count) 张卡片，支持向左滑动查看")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var tagEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("添加标签")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("输入标签（支持逗号分隔）", text: $tagInput)
                    .font(.caption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit(addInputTags)

                Button("添加") {
                    addInputTags()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("已添加标签会展示在上方标题卡片中，可直接点击标签右上角的 x 删除。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .zdGlassSurface(cornerRadius: 24, lineWidth: 0.9) // Changed from 14 to 24 matching top card
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.primaryColor.opacity(colorScheme == .dark ? 0.9 : 0.8),
                            theme.primaryColor.opacity(colorScheme == .dark ? 0.4 : 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .padding(.horizontal, 20)
    }

    private var existingTagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已有标签")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("点选可快速添加")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if availableExistingTags.isEmpty {
                Text("暂无已有标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                tagWrap(tags: availableExistingTags)
            }
        }
        .padding(14)
        .zdGlassSurface(cornerRadius: 24, lineWidth: 0.9) // Changed from 14 to 24 matching top card
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.primaryColor.opacity(colorScheme == .dark ? 0.9 : 0.8),
                            theme.primaryColor.opacity(colorScheme == .dark ? 0.4 : 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .padding(.horizontal, 20)
    }

    private var selectedTagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(selectedTags, id: \.self) { tag in
                    Text("# \(tag)")
                        .lineLimit(1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            useLightPreviewText
                                ? Color.white.opacity(0.9)
                                : Color.zdAccentDeep.opacity(0.9)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(useLightPreviewText ? 0.18 : 0.34))
                        .clipShape(Capsule())
                        .overlay(alignment: .topTrailing) {
                            Button {
                                removeTag(tag)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 14, height: 14)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 5, y: -5)
                        }
                }
            }
            .padding(.top, 5)
            .padding(.trailing, 5)
        }
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
            }
        )
    }

    @ViewBuilder
    private func tagWrap(tags: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 84), alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    addTags([tag])
                } label: {
                    HStack(spacing: 5) {
                        Text(tag)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primaryColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleCardActive(_ id: UUID) {
        if activeCardIDs.contains(id) {
            activeCardIDs.remove(id)
        } else {
            activeCardIDs.insert(id)
        }
    }

    private func addInputTags() {
        let pieces = tagInput
            .components(separatedBy: CharacterSet(charactersIn: ",，\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        addTags(pieces)
        tagInput = ""
    }

    private func addTags(_ tags: [String]) {
        guard !tags.isEmpty else {
            return
        }
        selectedTags = Self.sanitizedTags(from: selectedTags + tags)
    }

    private func removeTag(_ tag: String) {
        selectedTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private func confirmImport() {
        let tags = Self.sanitizedTags(from: selectedTags)
        onConfirm(activeCardIDs, tags)
        dismiss()
    }

    private static func sanitizedTags(from tags: [String], maxCount: Int = 24) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in tags {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                continue
            }
            let key = value.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(value)
            if result.count >= maxCount {
                break
            }
        }
        return result
    }
}
