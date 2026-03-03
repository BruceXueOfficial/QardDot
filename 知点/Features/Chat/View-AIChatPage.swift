import SwiftUI

struct AiChatPage: View {
    @StateObject private var viewModel = AiChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    
    @State private var showClearAlert = false
    @State private var showCardDrawer = false
    @State private var previewCard: KnowledgeCard?

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
                            
                            // Real-time voice preview as a user bubble
                            if !viewModel.pendingVoiceText.isEmpty {
                                ChatBubbleView(message: ChatMessage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, content: viewModel.pendingVoiceText, type: .user))
                                    .id("PendingVoiceBubble")
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                            
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
                        onStop: { viewModel.stopGeneration() },
                        onStartVoice: { viewModel.startVoiceRecording() },
                        onEndVoice: { viewModel.endVoiceRecording() },
                        onCancelVoice: { viewModel.cancelVoiceRecording() },
                        onOpenDrawer: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showCardDrawer = true
                            }
                        },
                        recognizedCardCount: viewModel.recognizedCards.count
                    )
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.isRecording)
                
            }
            .overlay(
                Group {
                    if showCardDrawer {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { showCardDrawer = false }
                            }
                            .transition(.opacity)
                        
                        VStack {
                            Spacer()
                            cardDrawerView
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            )
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
                KnowledgeCardDetailScreen(card: card)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .navigationBarBackButtonHidden()
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Card Collector Drawer
    private var cardDrawerView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("已识别卡片")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: {
                    withAnimation { showCardDrawer = false }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            
            // Cards List
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recognizedCards) { card in
                        Button(action: {
                            previewCard = card
                        }) {
                            KnowledgeCardSView(card: card)
                                .frame(width: 164)
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
                Text("共 \(viewModel.recognizedCards.count) 张卡片")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    // Collect cards
                    for card in viewModel.recognizedCards {
                        library.addCard(card)
                    }
                    withAnimation {
                        viewModel.recognizedCards.removeAll()
                        showCardDrawer = false
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }) {
                    Text("收纳卡片")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.zdAccentDeep))
                        .shadow(color: Color.zdAccentDeep.opacity(0.3), radius: 5, y: 3)
                }
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
}

#Preview {
    AiChatPage()
}
