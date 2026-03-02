import SwiftUI

struct AiChatPage: View {
    @StateObject private var viewModel = AiChatViewModel()
    @Environment(\.dismiss) private var dismiss

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
                    
                    // Show voice-recognized text live preview above input bar
                    if viewModel.isRecording && !viewModel.speechManager.recognizedText.isEmpty {
                        Text(viewModel.speechManager.recognizedText)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Material.ultraThin)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    AiFloatingInputBar(
                        text: $viewModel.inputText,
                        isRecording: viewModel.isRecording,
                        isGenerating: viewModel.isResponding,
                        onSend: { viewModel.sendMessage() },
                        onStop: { viewModel.stopGeneration() },
                        onStartVoice: { viewModel.startVoiceRecording() },
                        onEndVoice: { viewModel.endVoiceRecording() },
                        onCancelVoice: { viewModel.cancelVoiceRecording() }
                    )
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.isRecording)
                
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
            }
            .navigationBarBackButtonHidden()
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    AiChatPage()
}
