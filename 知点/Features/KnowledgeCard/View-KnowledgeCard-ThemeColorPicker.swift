import SwiftUI

// MARK: - Theme Picker
struct CardThemeColorPicker: View {
    @ObservedObject var viewModel: KnowledgeCardViewModel
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
                    previewMiniCard
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CardThemeColor.allCases) { color in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.updateThemeColor(color)
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

    private var previewMiniCard: some View {
        HStack {
            Spacer()
            KnowledgeCardSView(card: viewModel.card)
                .frame(width: ZDThemePickerLayout.cardPreviewWidth)
            Spacer()
        }
    }

    @ViewBuilder
    private func colorCircle(_ color: CardThemeColor) -> some View {
        let isSelected = (viewModel.card.themeColor ?? .defaultTheme) == color
        VStack(spacing: 6) {
            ZStack {
                ZDCardThemeSurfaceSwatch(
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


#Preview("KnowledgeCard Detail Screen - Theme Entry") {
    let previewCard = KnowledgeCard.previewShort
    KnowledgeCardDetailDrawerPreviewHost(card: previewCard)
}
