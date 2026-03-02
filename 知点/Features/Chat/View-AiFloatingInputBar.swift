import SwiftUI

enum AiInputMode {
    case text
    case voice
}

struct AiFloatingInputBar: View {
    @Binding var text: String
    
    // States
    var isRecording: Bool
    var isGenerating: Bool
    
    // Callbacks
    var onSend: () -> Void
    var onStop: () -> Void
    var onStartVoice: () -> Void
    var onEndVoice: () -> Void
    var onCancelVoice: () -> Void
    
    // Internal State
    @State private var inputMode: AiInputMode = .text
    @FocusState private var isInputFocused: Bool
    @State private var isDragCanceling = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack {
                if inputMode == .text {
                    textInputView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    voiceInputView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Text Input
    
    private var textInputView: some View {
        HStack(alignment: .center, spacing: 0) {
            TextField("与智能体问答，创建卡片", text: $text)
                .focused($isInputFocused)
                .submitLabel(.send)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .padding(.leading, 20)
                .padding(.trailing, 10)
                .frame(height: 56)
                .onSubmit { if !text.isEmpty { onSend() } }
            
            // Action Switcher
            Group {
                if !text.isEmpty {
                    sendButton
                } else if isGenerating {
                    stopButton
                } else {
                    switchToVoiceButton
                }
            }
            .padding(.trailing, 6)
            .transition(.scale)
        }
        .background(
            Capsule()
                .fill(Color(uiColor: .systemBackground))
        )
        // ZD specific glass effect over the base layer for neumorphism edge. (Fallback if UI base is transparent)
        .glassEffect(.regular, in: Capsule())
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(
                Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                lineWidth: 1
            )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Voice Input
    
    private var voiceInputView: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color.clear.contentShape(Rectangle())
                
                Text(voiceButtonText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 24)
                    .contentTransition(.numericText(value: 0))
                    .animation(.easeInOut(duration: 0.2), value: voiceButtonText)
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .gesture(voiceDragGesture)
            
            if isGenerating {
                stopButton.padding(.trailing, 6).transition(.scale)
            } else {
                switchToKeyboardButton.padding(.trailing, 6).transition(.scale)
            }
        }
        .background(
            Capsule()
                .fill(voiceButtonColor)
                .animation(.easeInOut(duration: 0.2), value: isDragCanceling)
        )
        .glassEffect(.clear, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
        .shadow(
            color: isDragCanceling ? Color.orange.opacity(0.5) : Color.zdAccentDeep.opacity(0.3),
            radius: 12,
            x: 0,
            y: 6
        )
        .scaleEffect(isRecording ? 1.02 : 1.0)
    }
    
    // MARK: - Logic & Helpers
    
    private var voiceButtonText: String {
        if !isRecording { return "长按输入语音" }
        return isDragCanceling ? "松开取消发送" : "松开发送，上滑取消"
    }
    
    private var voiceButtonColor: Color {
        isDragCanceling
            ? Color.orange.opacity(0.9)
            : Color.zdAccentDeep.opacity(0.9)
    }
    
    private var voiceDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isRecording {
                    onStartVoice()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
                let isCanceling = value.translation.height < -40
                if isDragCanceling != isCanceling {
                    isDragCanceling = isCanceling
                    UIImpactFeedbackGenerator(style: isCanceling ? .light : .light).impactOccurred()
                }
            }
            .onEnded { _ in
                if isDragCanceling {
                    onCancelVoice()
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else {
                    onEndVoice()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                withAnimation { isDragCanceling = false }
            }
    }
    
    // MARK: - Buttons
    
    private var sendButton: some View {
        actionCircleButton(icon: "arrow.up", color: Color.zdAccentDeep, iconColor: .white) { onSend() }
    }
    
    private var stopButton: some View {
        actionCircleButton(icon: "stop.fill", color: .secondary.opacity(0.2), iconColor: .primary) { onStop() }
    }
    
    private var switchToVoiceButton: some View {
        actionCircleButton(icon: "mic.fill", color: Color.zdAccentDeep, iconColor: .white) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                inputMode = .voice
                isInputFocused = false
            }
        }
    }
    
    private var switchToKeyboardButton: some View {
        actionCircleButton(icon: "keyboard", color: .white.opacity(0.2), iconColor: .white) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                inputMode = .text
                isInputFocused = true
            }
        }
    }
    
    private func actionCircleButton(icon: String, color: Color, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).foregroundColor(iconColor))
        }
        .buttonStyle(.plain)
    }
}

#Preview("AI Floating Input Bar") {
    struct PreviewWrapper: View {
        @State var text = ""
        var body: some View {
            ZStack(alignment: .bottom) {
                Color.gray.ignoresSafeArea()
                
                AiFloatingInputBar(
                    text: $text,
                    isRecording: false,
                    isGenerating: false,
                    onSend: {},
                    onStop: {},
                    onStartVoice: {},
                    onEndVoice: {},
                    onCancelVoice: {}
                )
            }
        }
    }
    
    return PreviewWrapper()
}
