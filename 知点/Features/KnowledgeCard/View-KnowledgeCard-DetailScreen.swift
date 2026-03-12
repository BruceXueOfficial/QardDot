import SwiftUI

struct KnowledgeCardDetailScreen: View {
    let card: KnowledgeCard
    var onCardUpdated: ((KnowledgeCard) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @StateObject private var viewModel: KnowledgeCardViewModel

    @State private var showDeleteConfirmation = false
    @State private var showThemeColorPicker = false
    @State private var selectedModuleID: UUID?
    @State private var undoDeleteStack: [EditorUndoAction] = []
    @State private var pendingImagePickerModuleID: UUID?
    @State private var pendingLinkedCardPickerModuleID: UUID?
    @State private var pendingLinkComposerModuleID: UUID?
    @State private var pendingTextFocusModuleID: UUID?
    @State private var keyboardIsVisible = false
    @State private var scrollProxy: ScrollViewProxy?

    init(card: KnowledgeCard, onCardUpdated: ((KnowledgeCard) -> Void)? = nil) {
        self.card = card
        self.onCardUpdated = onCardUpdated
        _viewModel = StateObject(wrappedValue: KnowledgeCardViewModel(card: card))
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
                let floatingControlHeight: CGFloat = 48
                let baseBottomContentInset = floatingBottomInset + floatingControlHeight + 24
                let focusedModuleScrollBuffer = max(220, proxy.size.height * 0.42)
                let contentBottomInset = baseBottomContentInset
                    + ((keyboardIsVisible || pendingTextFocusModuleID != nil) ? focusedModuleScrollBuffer : 0)

                ScrollViewReader { proxy in
                    ScrollView {
                        KnowledgeCardView(
                            viewModel: viewModel,
                            selectedModuleID: $selectedModuleID,
                            pendingImagePickerModuleID: $pendingImagePickerModuleID,
                            pendingLinkedCardPickerModuleID: $pendingLinkedCardPickerModuleID,
                            pendingLinkComposerModuleID: $pendingLinkComposerModuleID,
                            pendingTextFocusModuleID: $pendingTextFocusModuleID,
                            onDeleteModule: handleDeleteModule,
                            onRegisterUndoAction: handleRegisterUndoAction
                        )
                        .frame(width: contentWidth, alignment: .topLeading)
                        .padding(.top, 4)
                        .padding(.bottom, contentBottomInset)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { scrollProxy = proxy }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zdPageBackground()
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar(leadingInset: topBarLeadingInset, trailingInset: topBarTrailingInset)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        circleControlChrome(
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(destructiveControlTint),
                            borderColor: destructiveControlBorder,
                            shadowRadius: 6,
                            shadowY: 3
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, controlHorizontalInset + safeTrailing)
                    .padding(.bottom, floatingBottomInset)
                }
                .overlay(alignment: .bottomLeading) {
                    Menu {
                        Button("添加文字", systemImage: "text.alignleft") {
                            addModule(.text)
                        }
                        Button("添加图片", systemImage: "photo") {
                            addModule(.image)
                        }
                        Button("添加代码", systemImage: "curlybraces") {
                            addModule(.code)
                        }
                        Button("添加链接", systemImage: "link") {
                            addModule(.link)
                        }
                        Button("添加公式", systemImage: "function") {
                            addModule(.formula)
                        }
                        Button("添加关联", systemImage: "link.badge.plus") {
                            addModule(.linkedCard)
                        }
                    } label: {
                        circleControlChrome(
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(themeControlTint),
                            borderColor: themeControlBorder,
                            shadowRadius: 6,
                            shadowY: 3
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, controlHorizontalInset + safeLeading)
                    .padding(.bottom, floatingBottomInset)
                }
                .overlay(alignment: .bottom) {
                    if !undoDeleteStack.isEmpty {
                        Button {
                            undoDeleteModule()
                        } label: {
                            capsuleControlChrome(
                                Text("撤销")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(destructiveControlTint),
                                borderColor: destructiveControlBorder,
                                minWidth: 94,
                                minHeight: 48,
                                shadowRadius: 5,
                                shadowY: 2
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, floatingBottomInset)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardIsVisible = true
            // Scroll the active module into view above the keyboard
            if let id = selectedModuleID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollProxy?.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardIsVisible = false
        }
        .onChange(of: selectedModuleID) { _, newID in
            guard keyboardIsVisible, let id = newID else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.25)) {
                    scrollProxy?.scrollTo(id, anchor: .center)
                }
            }
        }
        .onAppear {
            library.recordView(for: viewModel.card)
        }
        .onDisappear {
            library.updateCard(viewModel.card)
            onCardUpdated?(viewModel.card)
            undoDeleteStack.removeAll()
        }
        .onChange(of: viewModel.card.themeColor) { _, _ in
            library.updateCard(viewModel.card)
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                library.deleteCard(id: card.id)
                dismiss()
            }
        } message: {
            Text("删除「\(viewModel.card.title)」后无法恢复，确认删除？")
        }
        .sheet(isPresented: $showThemeColorPicker) {
            CardThemeColorPicker(viewModel: viewModel)
        }
    }

    private func addModule(_ kind: CardBlockKind) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            let insertedID = viewModel.addModule(kind, after: selectedModuleID)
            selectedModuleID = insertedID
            if kind == .text {
                pendingTextFocusModuleID = insertedID
                scheduleScrollToModule(insertedID, delay: 0.08)
            } else if kind == .image {
                pendingImagePickerModuleID = insertedID
            } else if kind == .linkedCard {
                pendingLinkedCardPickerModuleID = insertedID
            } else if kind == .link {
                pendingLinkComposerModuleID = insertedID
            }
        }
    }

    private func scheduleScrollToModule(_ moduleID: UUID, delay: TimeInterval = 0.12) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.28)) {
                scrollProxy?.scrollTo(moduleID, anchor: .center)
            }
        }
    }

    private func handleDeleteModule(_ moduleID: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            if let snapshot = viewModel.removeModule(id: moduleID) {
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
                selectedModuleID = viewModel.restoreModule(snapshot)
            case .image(let snapshot):
                _ = viewModel.restoreImageToModule(snapshot)
                selectedModuleID = snapshot.moduleID
            case .codeEntry(let snapshot):
                _ = viewModel.restoreCodeEntry(snapshot)
                selectedModuleID = snapshot.moduleID
            }
        }
    }

    private func topBar(leadingInset: CGFloat, trailingInset: CGFloat) -> some View {
        ZStack {
            HStack(spacing: 12) {
                Button {
                    showThemeColorPicker = true
                } label: {
                    circleControlChrome(
                        Image(systemName: "paintpalette")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(themeControlTint),
                        borderColor: themeControlBorder,
                        shadowRadius: 4,
                        shadowY: 2
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 10)

                Button {
                    dismiss()
                } label: {
                    circleControlChrome(
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeControlTint),
                        borderColor: themeControlBorder,
                        shadowRadius: 4,
                        shadowY: 2
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(topBarBackground)
        .zIndex(4)
    }

    private var themeControlTint: Color {
        viewModel.card.resolvedPrimary
    }

    private var themeControlBorder: Color {
        themeControlTint.opacity(colorScheme == .dark ? 0.82 : 0.72)
    }

    private var destructiveControlTint: Color {
        Color.red.opacity(colorScheme == .dark ? 0.95 : 0.9)
    }

    private var destructiveControlBorder: Color {
        Color.red.opacity(colorScheme == .dark ? 0.82 : 0.72)
    }

    private var liquidGlassFillOpacity: Double {
        colorScheme == .dark ? 0.11 : 0.16
    }

    private var liquidGlassFallbackMaterialOpacity: Double {
        colorScheme == .dark ? 0.52 : 0.68
    }

    private var liquidGlassInnerHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.58)
    }

    private var floatingControlShadow: Color {
        .black.opacity(colorScheme == .dark ? 0.16 : 0.08)
    }

    @ViewBuilder
    private var liquidGlassCircleFill: some View {
        if #available(iOS 26.0, *) {
            Color.white
                .opacity(liquidGlassFillOpacity)
                .glassEffect(in: Circle())
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(liquidGlassFallbackMaterialOpacity)
        }
    }

    @ViewBuilder
    private var liquidGlassCapsuleFill: some View {
        if #available(iOS 26.0, *) {
            Color.white
                .opacity(liquidGlassFillOpacity)
                .glassEffect(in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(liquidGlassFallbackMaterialOpacity)
        }
    }

    private func circleControlChrome<Content: View>(
        _ content: Content,
        borderColor: Color,
        shadowRadius: CGFloat,
        shadowY: CGFloat
    ) -> some View {
        content
            .frame(width: 48, height: 48)
            .background(liquidGlassCircleFill)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(liquidGlassInnerHighlight, lineWidth: 0.85)
                    .padding(0.8)
            }
            .overlay {
                Circle()
                    .strokeBorder(borderColor, lineWidth: 1.12)
            }
            .shadow(color: floatingControlShadow, radius: shadowRadius, x: 0, y: shadowY)
    }

    private func capsuleControlChrome<Content: View>(
        _ content: Content,
        borderColor: Color,
        minWidth: CGFloat,
        minHeight: CGFloat,
        shadowRadius: CGFloat,
        shadowY: CGFloat
    ) -> some View {
        content
            .frame(minWidth: minWidth, minHeight: minHeight)
            .padding(.horizontal, 8)
            .background(liquidGlassCapsuleFill)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(liquidGlassInnerHighlight, lineWidth: 0.85)
                    .padding(0.8)
            }
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1.1)
            }
            .shadow(color: floatingControlShadow, radius: shadowRadius, x: 0, y: shadowY)
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
}

struct KnowledgeCardDetailDrawerPreviewHost: View {
    let card: KnowledgeCard

    var body: some View {
        ZStack {
            Color.zdPageBase.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                Text("卡片列表")
                    .font(.headline.weight(.semibold))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.zdAccentSoft.opacity(0.14))
                    .frame(height: 120)
                Spacer()
            }
            .padding(16)
        }
        .sheet(isPresented: .constant(true)) {
            KnowledgeCardDetailScreen(card: card)
                .environmentObject(KnowledgeCardLibraryStore(cards: [card]))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }
}

#Preview("KnowledgeCard Detail Screen") {
    let previewCard = KnowledgeCard.previewShort
    KnowledgeCardDetailDrawerPreviewHost(card: previewCard)
}
