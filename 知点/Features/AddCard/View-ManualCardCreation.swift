import SwiftUI

struct ManualCardCreationView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onCreate: ((KnowledgeCard) -> Void)?

    @State private var title = ""
    @FocusState private var focusedField: Field?
    
    @State private var keyboardIsVisible = false
    @State private var selectedModuleID: UUID?
    @State private var pendingImagePickerModuleID: UUID?
    @State private var pendingLinkComposerModuleID: UUID?
    @State private var pendingLinkedCardPickerModuleID: UUID?
    @State private var undoDeleteStack: [EditorUndoAction] = []

    @StateObject private var editorViewModel: KnowledgeCardViewModel = {
        let initialCard = KnowledgeCard(
            title: "",
            content: "",
            type: .short,
            tags: nil,
            themeColor: .defaultTheme,
            modules: [.text("")]
        )
        return KnowledgeCardViewModel(card: initialCard)
    }()

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

    private var hasContent: Bool {
        editorViewModel.modules.contains { block in
            switch block.kind {
            case .text: return !(block.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .image: return !(block.imageURLs ?? []).isEmpty
            case .code: return block.codeSnippets?.first?.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            case .link: return !(block.linkItems ?? []).isEmpty
            case .formula: return !(block.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .linkedCard: return true // a linked module implies it exists
            }
        }
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty && hasContent
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
                let safeBottom = proxy.safeAreaInsets.bottom
                let viewportWidth = max(0, proxy.size.width - safeLeading - safeTrailing)
                let controlHorizontalInset: CGFloat = 16
                let topBarLeadingInset = controlHorizontalInset + safeLeading
                let topBarTrailingInset = controlHorizontalInset + safeTrailing
                let contentWidth = viewportWidth
                let floatingBottomInset: CGFloat = keyboardIsVisible ? 12 : max(12, safeBottom - 24)

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
                .overlay(alignment: .bottomLeading) {
                    Menu {
                        Button("添加文字", systemImage: "text.alignleft") {
                            editorViewModel.addModule(.text)
                        }
                        Button("添加图片", systemImage: "photo") {
                            editorViewModel.addModule(.image)
                        }
                        Button("添加代码", systemImage: "curlybraces") {
                            editorViewModel.addModule(.code)
                        }
                        Button("添加链接", systemImage: "link") {
                            let insertedID = editorViewModel.addModule(.link)
                            selectedModuleID = insertedID
                            pendingLinkComposerModuleID = insertedID
                        }
                        Button("关联卡片", systemImage: "rectangle.on.rectangle") {
                            let insertedID = editorViewModel.addModule(.linkedCard)
                            selectedModuleID = insertedID
                            pendingLinkedCardPickerModuleID = insertedID
                        }
                        Button("添加公式", systemImage: "function") {
                            editorViewModel.addModule(.formula)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.zdAccentDeep)
                            .frame(width: 48, height: 48)
                            .background(Color.clear)
                            .clipShape(Circle())
                            .zdGlassSurface(cornerRadius: 999, lineWidth: 1.2, isClear: true)
                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                    }
                    .padding(.leading, controlHorizontalInset + safeLeading)
                    .padding(.bottom, floatingBottomInset)
                }
                .overlay(alignment: .bottom) {
                    if !undoDeleteStack.isEmpty {
                        Button {
                            undoDeleteModule()
                        } label: {
                            Text("撤销")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .frame(minWidth: 94, minHeight: 48)
                                .background(
                                    LiquidGlassChip(cornerRadius: 999)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.red.opacity(0.84), lineWidth: 1.1)
                                )
                        }
                        .buttonStyle(.plain)
                        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, floatingBottomInset)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardIsVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardIsVisible = false
        }
    }

    private var titleCard: some View {
        let cornerRadius: CGFloat = 24

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
        .zdPunchedGlassBackground(
            theme.cardBackgroundGradient,
            metrics: ZDPunchedCardMetrics(cornerRadius: cornerRadius, holeScale: 1.0),
            borderGradient: theme.cardBorderGradient
        )
    }

    private var contentModule: some View {
        KnowledgeCardView(
            viewModel: editorViewModel,
            selectedModuleID: $selectedModuleID,
            pendingImagePickerModuleID: $pendingImagePickerModuleID,
            pendingLinkedCardPickerModuleID: $pendingLinkedCardPickerModuleID,
            pendingLinkComposerModuleID: $pendingLinkComposerModuleID,
            hideTitle: true,
            hideOuterPadding: true,
            onDeleteModule: handleDeleteModule,
            onRegisterUndoAction: handleRegisterUndoAction
        )
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

        let newCard = KnowledgeCard(
            title: trimmedTitle,
            content: editorViewModel.modules.first(where: { $0.kind == .text })?.text ?? "",
            type: .short,
            tags: nil,
            themeColor: .defaultTheme,
            modules: editorViewModel.modules
        )

        library.addCard(newCard)
        onCreate?(newCard)
        dismiss()
    }
    
    private func handleDeleteModule(_ moduleID: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            if let snapshot = editorViewModel.removeModule(id: moduleID) {
                undoDeleteStack.append(.module(snapshot))
            }
            if selectedModuleID == moduleID {
                selectedModuleID = nil
            }
        }
    }

    private func handleRegisterUndoAction(_ action: EditorUndoAction) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            undoDeleteStack.append(action)
        }
    }

    private func undoDeleteModule() {
        guard let action = undoDeleteStack.popLast() else {
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            switch action {
            case .module(let snapshot):
                selectedModuleID = editorViewModel.restoreModule(snapshot)
            case .image(let snapshot):
                _ = editorViewModel.restoreImageToModule(snapshot)
                selectedModuleID = snapshot.moduleID
            case .codeEntry(let snapshot):
                _ = editorViewModel.restoreCodeEntry(snapshot)
                selectedModuleID = snapshot.moduleID
            }
        }
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
