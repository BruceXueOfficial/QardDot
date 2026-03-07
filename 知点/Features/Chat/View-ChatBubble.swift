import SwiftUI

struct ChatBubbleView: View {
    // Properties
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.type == .user { Spacer() }
            
            messageContent
            
            if message.type != .user { Spacer() }
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    // MARK: - Subviews
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Text Content
            if message.type == .user {
                Group {
                    if let attr = try? AttributedString(markdown: message.content.isEmpty ? " " : message.content, options: AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: true, interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)) {
                        Text(attr)
                    } else {
                        Text(LocalizedStringKey(message.content.isEmpty ? " " : message.content))
                    }
                }
                .textSelection(.enabled)
                .font(.system(size: 16))
                .lineSpacing(6)
                .kerning(0.5)
                .foregroundColor(.white)
                .animation(.linear(duration: 0.1), value: message.content)
            } else {
                Group {
                    if let attr = try? AttributedString(markdown: message.content.isEmpty ? " " : message.content, options: AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: true, interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)) {
                        Text(attr)
                    } else {
                        Text(message.content)
                    }
                }
                .textSelection(.enabled)
                .font(.system(size: 16))
                .lineSpacing(6)
                .kerning(0.5)
                .foregroundColor(Color(uiColor: UIColor.label.withAlphaComponent(0.9)))
                .animation(.linear(duration: 0.1), value: message.content)
            }
            
            // Disclaimer (AI Only)
            if message.type != .user && !message.isTyping {
                Text("回​​答​​由​​A​​I​​生​​成​​，​​仅​​供​​参​​考")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, message.type == .user ? 16 : 24)
        .background(backgroundLayer)
        .glassEffect(message.type == .user ? .identity : .clear, in: bubbleShape)
        .clipShape(bubbleShape)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : (message.type == .user ? 0.15 : 0.05)),
            radius: 8, x: 0, y: 4
        )
        .overlay(borderOverlay)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: message.isTyping)
        .scaleEffect(scale)
        .opacity(opacity)
    }
    
    // MARK: - Styles & Shapes
    
    @ViewBuilder
    private var backgroundLayer: some View {
        if message.type == .user {
            LinearGradient(
                colors: [
                    Color.zdAccentDeep,
                    Color.zdAccentDeep.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear
        }
    }
    
    private var borderOverlay: some View {
        bubbleShape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                        .white.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }
    
    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: message.type == .user ? 18 : 6,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: message.type == .user ? 6 : 18,
            style: .continuous
        )
    }
}

#Preview("Chat Bubble") {
    ZStack {
        Color.zdAccentDeep.opacity(0.1).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 16) {
                ChatBubbleView(message: ChatMessage(content: "知识图谱应该怎么用？有什么帮助吗", type: .user))
                ChatBubbleView(message: ChatMessage(content: "知识图谱可以帮你将松散的知识卡片按照双向链接关联起来，你可以从任意一张卡片出发，探索整个知识网络的脉络。目前功能开发中，敬请期待。", type: .ai))
            }
            .padding(.vertical, 20)
        }
}
}


