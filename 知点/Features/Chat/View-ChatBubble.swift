import SwiftUI
import UIKit
import LaTeXSwiftUI

// MARK: - ChatBubbleView

struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0

    private var bubbleTextMaxWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
            .first ?? 390
        return min(screenWidth * 0.72, 320)
    }

    private var shouldShowDisclaimer: Bool {
        message.type == .ai &&
        !message.isTyping &&
        !message.isStatusMessage &&
        !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
            if message.type == .user {
                // User bubble: plain verbatim text
                Text(verbatim: message.content.isEmpty ? " " : message.content)
                    .textSelection(.enabled)
                    .font(.system(size: 16))
                    .lineSpacing(6)
                    .kerning(0.5)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.linear(duration: 0.1), value: message.content)
            } else {
                if message.isTyping {
                    StreamingChatContentView(
                        text: message.content,
                        maxWidth: bubbleTextMaxWidth,
                        colorScheme: colorScheme
                    )
                    .animation(.linear(duration: 0.08), value: message.content)
                } else {
                    RichChatContentView(
                        text: message.content,
                        maxWidth: bubbleTextMaxWidth,
                        colorScheme: colorScheme
                    )
                    .transition(.opacity)
                }
            }

            // Disclaimer (AI Only)
            if shouldShowDisclaimer {
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

// MARK: - Rich Chat Content (LaTeX + Markdown)

private struct StreamingChatContentView: View {
    let text: String
    let maxWidth: CGFloat
    let colorScheme: ColorScheme

    private var textColor: Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor.label.withAlphaComponent(0.94))
            : Color(uiColor: UIColor.label.withAlphaComponent(0.9))
    }

    var body: some View {
        Text(verbatim: text.isEmpty ? " " : text)
            .textSelection(.enabled)
            .font(.system(size: 16))
            .lineSpacing(6)
            .kerning(0.5)
            .foregroundColor(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

/// Used for completed (non-streaming) AI responses.
/// Renders using MixedTextRenderer to ensure inline LaTeX formatting mirroring the text module.
private struct RichChatContentView: View {
    let text: String
    let maxWidth: CGFloat
    let colorScheme: ColorScheme

    private var textColor: Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor.label.withAlphaComponent(0.94))
            : Color(uiColor: UIColor.label.withAlphaComponent(0.9))
    }

    var body: some View {
        MixedTextRenderer(
            text: MarkdownChatBlock.preprocessMarkdown(text),
            fontSize: 16,
            textColor: textColor,
            lineSpacing: 6
        )
        .kerning(0.5)
        .textSelection(.enabled)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

// MARK: - Markdown Chat Block (handles bullets + blockquotes)

/// Renders a chunk of Markdown text that may contain `*`/`-` bullets and `>` blockquotes.
/// Converts these to proper Markdown syntax understood by AttributedString, then
/// falls back to a UITextView for selection support.
private struct MarkdownChatBlock: UIViewRepresentable {
    let markdown: String
    let maxWidth: CGFloat
    let colorScheme: ColorScheme

    private static let baseFont = UIFont.systemFont(ofSize: 16)
    private static let fullParsingOptions = AttributedString.MarkdownParsingOptions(
        allowsExtendedAttributes: true,
        interpretedSyntax: .full,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.isUserInteractionEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.maximumNumberOfLines = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.adjustsFontForContentSizeCategory = true
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.textDragInteraction?.isEnabled = false
        tv.linkTextAttributes = [.underlineStyle: NSUnderlineStyle.single.rawValue]
        tv.attributedText = buildAttributedText()
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let built = buildAttributedText()
        guard !uiView.attributedText.isEqual(to: built) else { return }
        uiView.attributedText = built
        uiView.invalidateIntrinsicContentSize()
        uiView.setNeedsLayout()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = max(maxWidth, 1)
        let fit = CGSize(width: w, height: .greatestFiniteMagnitude)
        uiView.textContainer.size = fit
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let measured = uiView.sizeThatFits(fit)
        return CGSize(width: w, height: ceil(measured.height))
    }

    // MARK: - Build

    private func buildAttributedText() -> NSAttributedString {
        let converted = Self.preprocessMarkdown(markdown)
        let textColor = UIColor.label.withAlphaComponent(colorScheme == .dark ? 0.94 : 0.9)

        let attributed: NSAttributedString
        if let attrStr = try? AttributedString(markdown: converted, options: Self.fullParsingOptions) {
            attributed = NSAttributedString(attrStr)
        } else {
            attributed = NSAttributedString(string: converted)
        }

        return styled(attributed, textColor: textColor)
    }

    /// Converts `* item` / `- item` bullets and `> quote` lines to GitHub-Flavored Markdown
    /// syntax accepted by Apple's AttributedString parser.
    static func preprocessMarkdown(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))

            // Bullet point: * item or - item (but not ** bold or --- hr)
            if (trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ")) && !trimmed.hasPrefix("---") {
                let content = String(trimmed.dropFirst(2))
                // Markdown list item with a bullet
                result.append("• \(content)")
                continue
            }

            // Blockquote: > text
            if trimmed.hasPrefix("> ") {
                let content = String(trimmed.dropFirst(2))
                // Use italic + gray tint via markdown (italic is what AttributedString supports)
                result.append("*\(content)*")
                continue
            }

            result.append(line)
        }

        return result.joined(separator: "\n")
    }

    private func styled(_ text: NSAttributedString, textColor: UIColor) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else {
            return NSAttributedString(string: " ", attributes: [
                .font: Self.baseFont,
                .foregroundColor: textColor,
                .kern: 0.5
            ])
        }

        mutable.addAttribute(.foregroundColor, value: textColor, range: fullRange)
        mutable.addAttribute(.kern, value: 0.5, range: fullRange)

        text.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let resolved = resolvedFont(from: value as? UIFont)
            mutable.addAttribute(.font, value: resolved, range: range)
        }

        text.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let para = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            para.lineSpacing = 6
            para.lineBreakMode = .byWordWrapping
            mutable.addAttribute(.paragraphStyle, value: para, range: range)
        }

        return mutable
    }

    private func resolvedFont(from font: UIFont?) -> UIFont {
        guard let font else { return Self.baseFont }
        let allowedTraits: UIFontDescriptor.SymbolicTraits = [.traitBold, .traitItalic, .traitMonoSpace]
        let traits = font.fontDescriptor.symbolicTraits.intersection(allowedTraits)
        guard let descriptor = Self.baseFont.fontDescriptor.withSymbolicTraits(traits) else {
            return Self.baseFont
        }
        return UIFont(descriptor: descriptor, size: Self.baseFont.pointSize)
    }
}

#Preview("Chat Bubble") {
    ZStack {
        Color.zdAccentDeep.opacity(0.1).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 16) {
                ChatBubbleView(message: ChatMessage(content: "知识图谱应该怎么用？有什么帮助吗", type: .user))
                ChatBubbleView(message: ChatMessage(
                    content: "生日悖论的核心推导：\n$$P(\\text{不同}) = \\frac{365}{365} \\times \\frac{364}{365} \\approx 0.4927$$\n\n常见例子：\n* 23人同生日概率超50%\n* 70人同生日概率超99%\n\n> 这是一个概率上的直觉偏差现象",
                    type: .ai,
                    isTyping: false
                ))
            }
            .padding(.vertical, 20)
        }
    }
}
