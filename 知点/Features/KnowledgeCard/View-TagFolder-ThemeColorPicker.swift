import SwiftUI

// MARK: - Tag Folder Theme Picker
struct TagFolderThemeColorPicker: View {
    let tagFolderModel: ZDTagCollectionFolderModel
    let currentTheme: CardThemeColor
    let onThemeSelected: (CardThemeColor) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview Folder
                    previewFolderCard
                        .padding(.top, 16)

                    // Color grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CardThemeColor.allCases) { color in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    onThemeSelected(color)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .presentationDetents([.height(ZDThemePickerLayout.compactSheetHeight), .large])
    }

    private var previewFolderCard: some View {
        GeometryReader { proxy in
            let previewWidth = ZDThemePickerLayout.tagFolderPreviewWidth(for: proxy.size.width)

            HStack {
                Spacer()
                ZDTagCollectionFolderSView(
                    model: tagFolderModel,
                    theme: currentTheme
                )
                .frame(width: previewWidth)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: KnowledgeCardSViewTokens.surfaceHeight)
    }

    @ViewBuilder
    private func colorCircle(_ color: CardThemeColor) -> some View {
        let isSelected = currentTheme == color
        VStack(spacing: 6) {
            ZStack {
                ZDTagFolderThemeSurfaceSwatch(
                    theme: color,
                    isSelected: isSelected
                )

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
}

#Preview("Tag Folder Theme Picker") {
    TagFolderThemeColorPicker(
        tagFolderModel: .demo,
        currentTheme: .defaultTheme,
        onThemeSelected: { _ in }
    )
}
