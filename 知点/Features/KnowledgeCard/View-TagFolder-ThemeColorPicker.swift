import SwiftUI

// MARK: - Tag Folder Theme Picker
struct TagFolderThemeColorPicker: View {
    let tagFolderModel: ZDTagCollectionFolderModel
    let currentTheme: CardThemeColor
    let onThemeSelected: (CardThemeColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    .padding(.bottom, 18)
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
        .presentationDetents([.medium, .large])
    }

    private var previewFolderCard: some View {
        HStack {
            Spacer()
            ZDTagCollectionFolderStyleCard(
                model: tagFolderModel,
                theme: currentTheme
            )
            Spacer()
        }
    }

    @ViewBuilder
    private func colorCircle(_ color: CardThemeColor) -> some View {
        let isSelected = currentTheme == color
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.tagFolderTopDeepColor.opacity(colorScheme == .dark ? 0.90 : 0.82),
                                color.tagFolderTopDeepColor,
                                color.tagFolderTopDeepColor.opacity(colorScheme == .dark ? 0.96 : 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(
                                color.tagFolderTopLightColor.opacity(0.8),
                                lineWidth: isSelected ? 3 : 1.2
                            )
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
}

#Preview("Tag Folder Theme Picker") {
    TagFolderThemeColorPicker(
        tagFolderModel: .demo,
        currentTheme: .defaultTheme,
        onThemeSelected: { _ in }
    )
}
