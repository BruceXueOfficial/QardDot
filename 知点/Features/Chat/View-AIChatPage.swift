import SwiftUI

struct AiChatPage: View {
    @StateObject private var viewModel = AiChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    
    @State private var showClearAlert = false
    @State private var showCardDrawer = false
    @State private var previewCard: KnowledgeCard?
    @State private var isCardSelectionMode = false
    @State private var selectedRecognizedCardIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                Color.clear.zdPageBackground()
                
                // Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            // Intro header
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 42))
                                    .foregroundStyle(Color.zdAccentDeep)
                                    .padding(.bottom, 6)
                                Text("智能助手")
                                    .font(.title2.weight(.bold))
                                Text("在知点里遇到不懂的卡片知识，随时问我")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            .padding(.bottom, 20)
                            
                            // Message List
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            // The Voice Bubble represents itself exactly inside `viewModel.messages` now.
                            
                            // AI Thinking Info
                            if viewModel.isThinking {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("思考中...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                            }
                            
                            // Bottom Marker
                            Color.clear
                                .frame(height: 120)
                                .id("BottomMarker")
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: viewModel.messages) { _, _ in
                        withAnimation {
                            proxy.scrollTo("BottomMarker", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isThinking) { _, isThinking in
                        if isThinking {
                            withAnimation {
                                proxy.scrollTo("BottomMarker", anchor: .bottom)
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("BottomMarker", anchor: .bottom)
                            }
                        }
                    }
                }
                .zdTopScrollBlurFade()
                
                // Overlay for recording UI or floating input
                VStack(spacing: 0) {
                    Spacer()
                    
                    AiFloatingInputBar(
                        text: $viewModel.inputText,
                        isRecording: viewModel.isRecording,
                        isGenerating: viewModel.isResponding,
                        onSend: { viewModel.sendMessage() },
                        onStop: { viewModel.stopGeneration(isInterrupt: true) },
                        onStartVoice: { viewModel.startVoiceRecording() },
                        onEndVoice: { viewModel.endVoiceRecording() },
                        onCancelVoice: { viewModel.cancelVoiceRecording() },
                        onOpenDrawer: {
                            selectedRecognizedCardIDs.removeAll()
                            isCardSelectionMode = false
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showCardDrawer = true
                            }
                        },
                        recognizedCardCount: viewModel.recognizedCards.count
                    )
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.isRecording)
                
            }
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    if showCardDrawer {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture { closeCardDrawer() }
                            .transition(.opacity)
                    }

                    cardDrawerView
                        .offset(y: showCardDrawer ? 0 : 440)
                        .opacity(showCardDrawer ? 1 : 0)
                        .allowsHitTesting(showCardDrawer)
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showCardDrawer)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("有问必答")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showClearAlert = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(viewModel.messages.isEmpty ? .secondary.opacity(0.3) : .primary)
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            .alert("您确定要清除对话内容吗？", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) { viewModel.clearMessages() }
            }
            .sheet(item: $previewCard) { card in
                KnowledgeCardDetailScreen(card: card) { updatedCard in
                    if let idx = viewModel.recognizedCards.firstIndex(where: { $0.id == updatedCard.id }) {
                        viewModel.recognizedCards[idx] = updatedCard
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
            }
            .onChange(of: viewModel.recognizedCards.map(\.id)) { _, ids in
                let validIDs = Set(ids)
                selectedRecognizedCardIDs.formIntersection(validIDs)
                if validIDs.isEmpty {
                    isCardSelectionMode = false
                    showCardDrawer = false
                }
            }
            .navigationBarBackButtonHidden()
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Card Collector Drawer
    private var cardDrawerView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .bottom, spacing: 10) {
                    Text("已识别卡片")
                        .font(.system(size: 18, weight: .bold))

                    Text(drawerStatusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(drawerStatusTextColor)
                        .padding(.bottom, 1)
                }

                Spacer()

                Button(action: { closeCardDrawer() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            // Cards List
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recognizedCards) { card in
                        Button(action: {
                            handleRecognizedCardTap(card)
                        }) {
                            KnowledgeCardSView(card: card)
                                .frame(width: 164)
                                .overlay(alignment: .topTrailing) {
                                    if isCardSelectionMode {
                                        selectionIndicator(for: card.id)
                                            .padding(.top, 8)
                                            .padding(.trailing, 8)
                                    }
                                }
                                .overlay {
                                    if isCardSelectionMode {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                selectedRecognizedCardIDs.contains(card.id)
                                                    ? Color.red.opacity(0.9)
                                                    : Color.primary.opacity(0.1),
                                                lineWidth: selectedRecognizedCardIDs.contains(card.id) ? 2 : 1
                                            )
                                    }
                                }
                                .scaleEffect(
                                    isCardSelectionMode && selectedRecognizedCardIDs.contains(card.id)
                                        ? 0.98
                                        : 1.0
                                )
                                .animation(.spring(response: 0.24, dampingFraction: 0.85), value: selectedRecognizedCardIDs)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(height: 160)
            
            Divider()
            
            // Bottom Action
            HStack {
                ZDIconButton(
                    systemName: isCardSelectionMode ? "xmark" : "checkmark.circle",
                    active: isCardSelectionMode
                ) {
                    toggleCardSelectionMode()
                }

                Spacer()

                Button(action: { handleDrawerPrimaryAction() }) {
                    Text(drawerPrimaryButtonTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(drawerPrimaryButtonColor))
                        .shadow(color: drawerPrimaryButtonColor.opacity(0.3), radius: 5, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemBackground).opacity(0.85))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 50)
    }

    private var drawerStatusText: String {
        if isCardSelectionMode {
            return "已选择 \(selectedRecognizedCardIDs.count) 张卡片"
        }
        return "共 \(viewModel.recognizedCards.count) 张卡片"
    }

    private var drawerStatusTextColor: Color {
        if isCardSelectionMode && !selectedRecognizedCardIDs.isEmpty {
            return .red
        }
        return .secondary
    }

    private var drawerPrimaryButtonTitle: String {
        if isCardSelectionMode {
            return selectedRecognizedCardIDs.isEmpty ? "选择卡片" : "删除卡片"
        }
        return "收纳卡片"
    }

    private var drawerPrimaryButtonColor: Color {
        if isCardSelectionMode {
            return selectedRecognizedCardIDs.isEmpty
                ? Color.gray.opacity(0.72)
                : Color.red
        }
        return Color.zdAccentDeep
    }

    @ViewBuilder
    private func selectionIndicator(for cardID: UUID) -> some View {
        let isSelected = selectedRecognizedCardIDs.contains(cardID)
        Circle()
            .fill(Color(uiColor: .systemBackground))
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.red : Color.secondary.opacity(0.45), lineWidth: 1.2)
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
    }

    private func closeCardDrawer() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            showCardDrawer = false
        }
        isCardSelectionMode = false
        selectedRecognizedCardIDs.removeAll()
    }

    private func toggleCardSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            isCardSelectionMode.toggle()
            if !isCardSelectionMode {
                selectedRecognizedCardIDs.removeAll()
            }
        }
    }

    private func handleRecognizedCardTap(_ card: KnowledgeCard) {
        if isCardSelectionMode {
            if selectedRecognizedCardIDs.contains(card.id) {
                selectedRecognizedCardIDs.remove(card.id)
            } else {
                selectedRecognizedCardIDs.insert(card.id)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        previewCard = card
    }

    private func handleDrawerPrimaryAction() {
        if isCardSelectionMode {
            guard !selectedRecognizedCardIDs.isEmpty else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }

            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                viewModel.recognizedCards.removeAll { selectedRecognizedCardIDs.contains($0.id) }
                selectedRecognizedCardIDs.removeAll()
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            return
        }

        for card in viewModel.recognizedCards {
            library.addCard(card)
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            viewModel.recognizedCards.removeAll()
        }
        closeCardDrawer()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

#Preview {
    AiChatPage()
}
