import SwiftUI

struct ManualCardCreationView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onCreate: ((KnowledgeCard) -> Void)?

    @State private var title = ""
    @State private var content = ""
    @FocusState private var focusedField: Field?

    private var theme: CardThemeColor {
        .defaultTheme
    }

    private enum Field {
        case title
        case content
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty && !trimmedContent.isEmpty
    }

    private var useLightTitleCardText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    private var titleCardPrimaryTextColor: Color {
        useLightTitleCardText ? Color.white.opacity(0.95) : .primary
    }

    private var titleCardSecondaryTextColor: Color {
        useLightTitleCardText ? Color.white.opacity(0.82) : .secondary
    }

    private var titleTagTextColor: Color {
        useLightTitleCardText ? Color.white.opacity(0.9) : Color.zdAccentDeep.opacity(0.9)
    }

    private var titleTagBackgroundColor: Color {
        Color.white.opacity(useLightTitleCardText ? 0.18 : 0.34)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeLeading = proxy.safeAreaInsets.leading
                let safeTrailing = proxy.safeAreaInsets.trailing
                let viewportWidth = max(0, proxy.size.width - safeLeading - safeTrailing)
                let controlHorizontalInset: CGFloat = 16
                let topBarLeadingInset = controlHorizontalInset + safeLeading
                let topBarTrailingInset = controlHorizontalInset + safeTrailing
                let contentWidth = viewportWidth

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        titleCard
                        contentModule
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: contentWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zdPageBackground()
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar(leadingInset: topBarLeadingInset, trailingInset: topBarTrailingInset)
                }
            }
        }
    }

    private var titleCard: some View {
        let cornerRadius: CGFloat = 24
        let holeSize: CGFloat = 16.5
        let holeInset: CGFloat = 14

        return VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if trimmedTitle.isEmpty {
                    Text("请输入标题")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(Color.gray.opacity(0.7))
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }

                TextField("", text: $title, axis: .vertical)
                    .focused($focusedField, equals: .title)
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(titleCardPrimaryTextColor)
                    .lineLimit(1...3)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .content
                    }
            }

            HStack(alignment: .center, spacing: 8) {
                Group {
                    if trimmedTitle.isEmpty {
                        Text("点击输入卡片标题")
                            .font(.caption)
                            .foregroundStyle(titleCardSecondaryTextColor)
                    } else {
                        Text("# 知识卡片")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(titleTagTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(titleTagBackgroundColor)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button { } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(useLightTitleCardText ? Color.white.opacity(0.9) : .secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            useLightTitleCardText
                                ? Color.white.opacity(0.18)
                                : Color.secondary.opacity(0.1)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(true)
                .opacity(0.72)

                Spacer(minLength: 8)

                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(titleCardSecondaryTextColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TitleCardPunchedShape(cornerRadius: cornerRadius, holeSize: holeSize, holeInset: holeInset)
                .fill(theme.cardBackgroundGradient, style: FillStyle(eoFill: true))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            TitleCardPunchedShape(cornerRadius: cornerRadius, holeSize: holeSize, holeInset: holeInset)
                .stroke(theme.cardBorderGradient.opacity(0.58), lineWidth: 0.78)
        )
        .overlay(
            TitleCardPunchedShape(cornerRadius: cornerRadius, holeSize: holeSize, holeInset: holeInset)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.white.opacity(0.2),
                    lineWidth: 0.4
                )
                .padding(1)
        )
        .overlay(alignment: .topTrailing) {
            KnowledgeCardPinHoleInnerShadow(size: holeSize)
                .padding(.top, holeInset)
                .padding(.trailing, holeInset)
                .allowsHitTesting(false)
        }
    }

    private var contentModule: some View {
        ManualCreationModuleContainer(title: "正文") {
            ZStack(alignment: .topLeading) {
                NotionLikeTextEditor(
                    text: $content,
                    isEditable: true,
                    minimumHeight: 156
                )
                .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)

                if trimmedContent.isEmpty {
                    Text("请输入正文")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = .content
            }
        }
    }

    private func topBar(leadingInset: CGFloat, trailingInset: CGFloat) -> some View {
        ZStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.zdAccentDeep.opacity(0.92))
                        .frame(width: 48, height: 48)
                        .background(Color.clear)
                        .clipShape(Circle())
                        .zdGlassSurface(cornerRadius: 999, lineWidth: 1.2, isClear: true)
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 10)

                Button {
                    createCard()
                } label: {
                    Text("完成")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(canCreate ? Color.zdAccentDeep.opacity(0.92) : Color.secondary.opacity(0.45))
                        .frame(minWidth: 72, minHeight: 48)
                        .background(Color.clear)
                        .clipShape(Capsule())
                        .zdGlassSurface(cornerRadius: 999, lineWidth: 1.2, isClear: true)
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .opacity(canCreate ? 1 : 0.78)
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(topBarBackground)
        .zIndex(4)
    }

    @ViewBuilder
    private var topBarBackground: some View {
        let fadeTailHeight: CGFloat = 48
        let baseTintOpacity = colorScheme == .dark ? 0.08 : 0.1
        let fallbackMaterialOpacity = colorScheme == .dark ? 0.3 : 0.36
        let topHighlightOpacity = colorScheme == .dark ? 0.04 : 0.08
        let topMaskOpacity = colorScheme == .dark ? 0.78 : 0.72
        let midMaskOpacity = colorScheme == .dark ? 0.28 : 0.22

        ZStack {
            Color.zdPageBase.opacity(baseTintOpacity)

            if #available(iOS 26.0, *) {
                Color.white.opacity(colorScheme == .dark ? 0.006 : 0.008)
                    .glassEffect(in: Rectangle())
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(fallbackMaterialOpacity)
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(topHighlightOpacity),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .padding(.bottom, -fadeTailHeight)
        .mask(
            VStack(spacing: 0) {
                Color.black
                    .opacity(topMaskOpacity)

                LinearGradient(
                    colors: [
                        Color.black.opacity(topMaskOpacity),
                        Color.black.opacity(midMaskOpacity),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeTailHeight)
            }
        )
        .ignoresSafeArea(edges: .top)
    }

    private func createCard() {
        guard canCreate else {
            return
        }

        let modules: [CardBlock] = [
            .text(trimmedContent)
        ]

        let newCard = KnowledgeCard(
            title: trimmedTitle,
            content: trimmedContent,
            type: .short,
            tags: nil,
            themeColor: .defaultTheme,
            modules: modules
        )

        library.addCard(newCard)
        onCreate?(newCard)
        dismiss()
    }
}

private struct ManualCreationModuleContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.zdAccentDeep.opacity(0.42),
                            Color.zdAccentSoft.opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.82
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.18),
                    lineWidth: 0.4
                )
                .padding(1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.06),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

#Preview("Manual Card Creation") {
    ManualCardCreationView()
        .environmentObject(KnowledgeCardLibraryStore())
}
