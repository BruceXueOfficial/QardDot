import SwiftUI

// MARK: - Theme Picker
struct CardThemeColorPicker: View {
    @ObservedObject var viewModel: KnowledgeCardViewModel
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
                    // Preview card
                    previewMiniCard
                        .padding(.top, 8)

                    // Color grid
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
                    .padding(.bottom, 18)
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
        .presentationDetents([.medium, .large])
    }

    private var previewMiniCard: some View {
        let theme = viewModel.card.themeColor ?? .defaultTheme
        let useLightText = theme.prefersLightForeground(in: colorScheme)
        return VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.card.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(useLightText ? Color.white.opacity(0.94) : Color.black.opacity(0.82))
                .lineLimit(2)
            Text(theme.displayName)
                .font(.caption)
                .foregroundStyle(useLightText ? Color.white.opacity(0.82) : theme.primaryColor.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.cardBackgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.cardBorderGradient, lineWidth: 1.35)
        )
        .shadow(color: theme.primaryColor.opacity(0.18), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private func colorCircle(_ color: CardThemeColor) -> some View {
        let isSelected = (viewModel.card.themeColor ?? .defaultTheme) == color
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
}

#Preview("KnowledgeCard Detail Screen - Theme Entry") {
    let previewCard = KnowledgeCard.previewShort
    KnowledgeCardDetailDrawerPreviewHost(card: previewCard)
}
