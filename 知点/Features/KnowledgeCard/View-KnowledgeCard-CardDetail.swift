import SwiftUI
import Combine
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Detail Content View
struct KnowledgeCardView: View {
    @ObservedObject var viewModel: KnowledgeCardViewModel
    @Binding var selectedModuleID: UUID?
    @Binding var pendingImagePickerModuleID: UUID?
    @Binding var pendingLinkedCardPickerModuleID: UUID?
    let onDeleteModule: ((UUID) -> Void)?
    let onRegisterUndoAction: ((EditorUndoAction) -> Void)?
    var hideTitle: Bool = false
    var hideOuterPadding: Bool = false
    @EnvironmentObject var library: KnowledgeCardLibraryStore
    @Environment(\.colorScheme) var colorScheme

    @State var previewImageSource: String?

    @State var isEditingTitle = false
    @State var titleDraft = ""
    @State var isTagDeleteMode = false
    @State private var tagEditorPreviewCard: KnowledgeCard?

    @State var imagePickerTargetModuleID: UUID?
    @State var imageSourceMenuModuleID: UUID?
    @State var systemImagePickerSource: SystemImagePicker.SourceType?
    @State var isShowingSystemImagePicker = false
    @State var isShowingFileImporter = false
    @State var removingImageTarget: ModuleImageTarget?
    @State var codeEditingStates: [UUID: Bool] = [:]
    @State var codeWrapStates: [UUID: Bool] = [:]
    @State var codeEditorHeights: [UUID: CGFloat] = [:]
    @State var copiedCodeSnippetIDs: Set<UUID> = []
    @State var removingCodeSnippetTarget: ModuleCodeSnippetTarget?
    @State var linkInputTargetModuleID: UUID?
    @State var linkInputTitleDraft = ""
    @State var linkInputURLDraft = ""
    @State var linkInputErrorMessage: String?
    @State var activeLinkBrowserDestination: LinkBrowserDestination?
    @State var showLinkedCardPicker = false
    @State var activeLinkedCardDestination: KnowledgeCard?

    @State var formulaEditingModuleIDs: Set<UUID> = []
    @State var formulaDrafts: [UUID: String] = [:]
    @State var formulaErrorModuleIDs: Set<UUID> = []

    init(
        viewModel: KnowledgeCardViewModel,
        selectedModuleID: Binding<UUID?> = .constant(nil),
        pendingImagePickerModuleID: Binding<UUID?> = .constant(nil),
        pendingLinkedCardPickerModuleID: Binding<UUID?> = .constant(nil),
        hideTitle: Bool = false,
        hideOuterPadding: Bool = false,
        onDeleteModule: ((UUID) -> Void)? = nil,
        onRegisterUndoAction: ((EditorUndoAction) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self._selectedModuleID = selectedModuleID
        self._pendingImagePickerModuleID = pendingImagePickerModuleID
        self._pendingLinkedCardPickerModuleID = pendingLinkedCardPickerModuleID
        self.hideTitle = hideTitle
        self.hideOuterPadding = hideOuterPadding
        self.onDeleteModule = onDeleteModule
        self.onRegisterUndoAction = onRegisterUndoAction
    }

    var card: KnowledgeCard {
        viewModel.card
    }

    var resolvedTheme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !hideTitle {
                titleModuleView
            }

            moduleCardLayout
        }
        .padding(.horizontal, hideOuterPadding ? 0 : 16)
        .padding(.vertical, hideOuterPadding ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            titleDraft = card.title
            viewModel.ensureModulesIfNeeded()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { previewImageSource != nil },
                set: { isPresented in
                    if !isPresented {
                        previewImageSource = nil
                    }
                }
            )
        ) {
            if let source = previewImageSource {
                FullscreenImageViewer(source: source) {
                    previewImageSource = nil
                }
            }
        }
        .onChange(of: pendingImagePickerModuleID) { _, newValue in
            guard let moduleID = newValue else { return }
            presentImageSourcePicker(for: moduleID)
            pendingImagePickerModuleID = nil
        }
        .onChange(of: pendingLinkedCardPickerModuleID) { _, newValue in
            if newValue != nil {
                showLinkedCardPicker = true
                pendingLinkedCardPickerModuleID = nil
            }
        }
        .sheet(isPresented: $isShowingSystemImagePicker) {
            if let source = systemImagePickerSource {
                SystemImagePicker(sourceType: source) { image in
                    handlePickedImage(image)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { linkInputTargetModuleID != nil },
                set: { isPresented in
                    if !isPresented {
                        resetLinkComposerDrafts()
                    }
                }
            )
        ) {
            LinkEntryComposerSheet(
                title: $linkInputTitleDraft,
                url: $linkInputURLDraft,
                errorMessage: linkInputErrorMessage
            ) {
                resetLinkComposerDrafts()
            } onConfirm: {
                commitPendingLinkEntry()
            }
        }
        .sheet(item: $activeLinkBrowserDestination) { destination in
            LinkInAppBrowserSheet(destination: destination)
        }
        .sheet(isPresented: $showLinkedCardPicker) {
            CardLinkPickerSheet(
                excludedCardIDs: viewModel.card.linkedCardIDs.map(Set.init) ?? [],
                onLink: {
                    viewModel.addLinkedCards($0)
                }
            )
        }
        .sheet(item: $activeLinkedCardDestination) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .sheet(item: $tagEditorPreviewCard) { previewCard in
            ImportTagPreviewScreen(
                card: previewCard,
                existingTags: library.allUniqueTags()
            ) { finalizedCard in
                viewModel.replaceTags(finalizedCard.tags ?? [])
                withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                    isTagDeleteMode = false
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.image]
        ) { result in
            handlePickedImageFile(result)
        }
    }
}

// MARK: - Header
private extension KnowledgeCardView {
    var useLightTitleCardText: Bool {
        resolvedTheme.prefersLightForeground(in: colorScheme)
    }

    var titleCardPrimaryTextColor: Color {
        useLightTitleCardText ? Color.white.opacity(0.95) : .primary
    }

    var titleCardSecondaryTextColor: Color {
        useLightTitleCardText ? Color.white.opacity(0.82) : .secondary
    }

    var titleTagTextColor: Color {
        useLightTitleCardText ? Color.white.opacity(0.9) : Color.zdAccentDeep.opacity(0.9)
    }

    var titleTagBackgroundColor: Color {
        Color.white.opacity(useLightTitleCardText ? 0.18 : 0.34)
    }

    var titleModuleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditingTitle {
                InlineTitleEditor(
                    text: $titleDraft,
                    maxLines: 3,
                    prefersLightText: useLightTitleCardText,
                    onCommit: {
                        viewModel.updateTitle(titleDraft)
                        titleDraft = viewModel.card.title
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                            isEditingTitle = false
                        }
                    }
                )
            } else {
                Text(card.title)
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(titleCardPrimaryTextColor)
                    .lineLimit(3)
                    .onTapGesture {
                        titleDraft = card.title
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                            isEditingTitle = true
                        }
                    }
            }

            HStack(alignment: .center, spacing: 8) {
                Group {
                    let tags = card.tags ?? []
                    if tags.isEmpty {
                        Text("点击加号新增标签")
                            .font(.caption)
                            .foregroundStyle(titleCardSecondaryTextColor)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                                    Text("# \(tag)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(titleTagTextColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(titleTagBackgroundColor)
                                        .clipShape(Capsule())
                                        .overlay(alignment: .topTrailing) {
                                            if isTagDeleteMode {
                                                Button {
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                                                        viewModel.removeTag(at: index)
                                                        if (viewModel.card.tags ?? []).isEmpty {
                                                            isTagDeleteMode = false
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 7, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .frame(width: 14, height: 14)
                                                        .background(Color.red)
                                                        .clipShape(Circle())
                                                }
                                                .offset(x: 5, y: -5)
                                                .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                }
                            }
                            .padding(.top, isTagDeleteMode ? 5 : 0)
                            .padding(.trailing, isTagDeleteMode ? 5 : 0)
                        }
                        .mask(
                            HStack(spacing: 0) {
                                Color.black
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 20)
                            }
                        )
                        .onLongPressGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                                isTagDeleteMode.toggle()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 常驻灰色加号按钮
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                        isTagDeleteMode = false
                    }
                    tagEditorPreviewCard = viewModel.card
                } label: {
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

                Text(card.createdAt.formatted(date: .abbreviated, time: .omitted))
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
            resolvedTheme.cardBackgroundGradient,
            metrics: ZDPunchedCardMetrics(cornerRadius: 24, holeScale: 1.0),
            borderGradient: resolvedTheme.cardBorderGradient
        )
    }

}

// MARK: - Inline Title Editor
/// A multi-line title editor that maintains the same visual layout as the
/// display-only `Text` view – same font, same line-wrapping, same line count.
struct InlineTitleEditor: UIViewRepresentable {
    @Binding var text: String
    var maxLines: Int = 3
    var prefersLightText: Bool = false
    var onCommit: (() -> Void)?

    private static let titleFont = UIFont.systemFont(ofSize: 38, weight: .heavy)

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = Self.titleFont
        tv.textColor = prefersLightText ? UIColor.white : UIColor.label
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.maximumNumberOfLines = maxLines
        tv.textContainer.lineBreakMode = .byTruncatingTail
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.returnKeyType = .done
        tv.delegate = context.coordinator
        tv.text = text
        // Auto-focus when appearing
        DispatchQueue.main.async {
            tv.becomeFirstResponder()
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.textColor = prefersLightText ? UIColor.white : UIColor.label
        // Only update from external binding when the user is NOT currently editing.
        guard !uiView.isFirstResponder else { return }
        if uiView.text != text {
            uiView.text = text
            uiView.invalidateIntrinsicContentSize()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth: CGFloat
        if let w = proposal.width, w > 0 {
            targetWidth = w
        } else if uiView.bounds.width > 0 {
            targetWidth = uiView.bounds.width
        } else {
            return nil
        }
        let fitting = CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        let measured = uiView.sizeThatFits(fitting)
        return CGSize(width: targetWidth, height: ceil(measured.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: InlineTitleEditor
        init(_ parent: InlineTitleEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            textView.invalidateIntrinsicContentSize()
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // Intercept Return key → commit editing instead of inserting newline
            if text == "\n" {
                parent.onCommit?()
                textView.resignFirstResponder()
                return false
            }
            return true
        }
    }
}

// MARK: - Markdown Text Editor
struct NotionLikeTextEditor: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var minimumHeight: CGFloat = 100

    fileprivate static let baseFontSize: CGFloat = 16
    fileprivate static let caretTopInset: CGFloat = 2
    fileprivate static let labelColor = UIColor.label.withAlphaComponent(0.9)
    fileprivate static let quoteMarkerAttribute = NSAttributedString.Key("NotionQuoteMarker")
    fileprivate static let tableLineAttribute = NSAttributedString.Key("NotionTableLine")

    fileprivate static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: baseFontSize, weight: .regular),
            .foregroundColor: labelColor
        ]
    }

    private final class MarkdownTextView: UITextView {
        override func layoutSubviews() {
            super.layoutSubviews()
            // Quote bar geometry depends on current line wrapping width.
            setNeedsDisplay()
        }

        override func caretRect(for position: UITextPosition) -> CGRect {
            var rect = super.caretRect(for: position)

            let source = textStorage.string as NSString
            let cursor = min(max(offset(from: beginningOfDocument, to: position), 0), source.length)

            var lineStart = cursor
            while lineStart > 0 {
                let prev = source.character(at: lineStart - 1)
                if prev == 0x0A || prev == 0x0D {
                    break
                }
                lineStart -= 1
            }

            var lineEnd = cursor
            while lineEnd < source.length {
                let code = source.character(at: lineEnd)
                if code == 0x0A || code == 0x0D {
                    break
                }
                lineEnd += 1
            }

            // 光标高度应与所在行真实字体保持一致，避免正文行错误显示为标题高度。
            if let targetFont = caretFont(
                cursor: cursor,
                lineStart: lineStart,
                lineEnd: lineEnd,
                source: source
            ) {
                let targetHeight = ceil(targetFont.lineHeight)
                if targetHeight > 0, abs(rect.height - targetHeight) > 0.5 {
                    let delta = targetHeight - rect.height
                    rect.origin.y -= delta * 0.5
                    rect.size.height = targetHeight
                }
            }

            return rect
        }

        private func caretFont(
            cursor: Int,
            lineStart: Int,
            lineEnd: Int,
            source: NSString
        ) -> UIFont? {
            // 非空行：优先取光标附近实际字符的字体属性。
            if lineStart < lineEnd, textStorage.length > 0 {
                let anchor: Int
                if cursor > lineStart {
                    anchor = min(cursor - 1, lineEnd - 1)
                } else {
                    anchor = lineStart
                }
                if anchor >= 0, anchor < textStorage.length,
                   let font = textStorage.attribute(.font, at: anchor, effectiveRange: nil) as? UIFont {
                    return font
                }
            }

            // 空行：先取该行换行符上的继承样式，再退回 typing/font。
            if lineStart >= 0, lineStart < source.length {
                let code = source.character(at: lineStart)
                if code == 0x0A || code == 0x0D,
                   let font = textStorage.attribute(.font, at: lineStart, effectiveRange: nil) as? UIFont {
                    return font
                }
            }
            return (typingAttributes[.font] as? UIFont) ?? font
        }

        override func draw(_ rect: CGRect) {
            super.draw(rect)

            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }
            let storage = textStorage

            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else {
                return
            }

            context.saveGState()
            UIColor.systemGray3.setFill()

            let nsString = storage.string as NSString
            let quoteBarX = textContainerInset.left + 2
            var quoteSegments: [(top: CGFloat, bottom: CGFloat)] = []

            func appendQuoteSegment(top: CGFloat, bottom: CGFloat) {
                guard bottom > top else {
                    return
                }
                quoteSegments.append((top: top, bottom: bottom))
            }

            func lineHasQuoteStyle(_ rawLineRange: NSRange) -> Bool {
                guard rawLineRange.length > 0 else {
                    return false
                }

                var hasMarker = false
                storage.enumerateAttribute(
                    NotionLikeTextEditor.quoteMarkerAttribute,
                    in: rawLineRange
                ) { value, _, stop in
                    if (value as? Bool) == true {
                        hasMarker = true
                        stop.pointee = true
                    }
                }
                if hasMarker {
                    return true
                }

                var location = rawLineRange.location
                let upperBound = rawLineRange.location + rawLineRange.length
                while location < upperBound {
                    var effective = NSRange(location: 0, length: 0)
                    let paragraph = storage.attribute(
                        .paragraphStyle,
                        at: location,
                        effectiveRange: &effective
                    ) as? NSParagraphStyle
                    let firstIndent = paragraph?.firstLineHeadIndent ?? 0
                    let headIndent = paragraph?.headIndent ?? 0
                    if firstIndent >= 9, headIndent >= 9 {
                        return true
                    }
                    let next = effective.location + effective.length
                    if next <= location {
                        location += 1
                    } else {
                        location = next
                    }
                }

                return false
            }

            var location = 0

            while location < nsString.length {
                let rawLineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
                defer { location = rawLineRange.location + rawLineRange.length }

                guard rawLineRange.length > 0 else {
                    continue
                }
                let isQuoteLine = lineHasQuoteStyle(rawLineRange)
                guard isQuoteLine else {
                    continue
                }

                layoutManager.ensureLayout(forCharacterRange: rawLineRange)
                let glyphRange = layoutManager.glyphRange(
                    forCharacterRange: rawLineRange,
                    actualCharacterRange: nil
                )
                guard glyphRange.length > 0 else {
                    continue
                }

                layoutManager.enumerateLineFragments(
                    forGlyphRange: glyphRange
                ) { _, usedRect, _, _, _ in
                    let top = self.textContainerInset.top + usedRect.minY + 1
                    let bottom = self.textContainerInset.top + usedRect.maxY - 1
                    appendQuoteSegment(top: top, bottom: bottom)
                }
            }

            // 当前为空引用行时（还未输入内容），也即时绘制灰色引用条。
            if (typingAttributes[NotionLikeTextEditor.quoteMarkerAttribute] as? Bool) == true {
                let cursor = min(max(selectedRange.location, 0), nsString.length)
                var lineStart = cursor
                while lineStart > 0 {
                    let prev = nsString.character(at: lineStart - 1)
                    if prev == 0x0A || prev == 0x0D { break }
                    lineStart -= 1
                }
                var lineEnd = cursor
                while lineEnd < nsString.length {
                    let code = nsString.character(at: lineEnd)
                    if code == 0x0A || code == 0x0D { break }
                    lineEnd += 1
                }

                if lineEnd == lineStart,
                   let position = position(from: beginningOfDocument, offset: cursor) {
                    let caret = caretRect(for: position)
                    let top = caret.minY + 1
                    let bottom = top + max(caret.height - 2, 12)
                    appendQuoteSegment(top: top, bottom: bottom)
                }
            }

            if !quoteSegments.isEmpty {
                let sorted = quoteSegments.sorted { lhs, rhs in
                    lhs.top < rhs.top
                }

                var merged: [(top: CGFloat, bottom: CGFloat)] = []
                for segment in sorted {
                    guard var last = merged.last else {
                        merged.append(segment)
                        continue
                    }

                    if segment.top <= last.bottom + 3 {
                        last.bottom = max(last.bottom, segment.bottom)
                        merged[merged.count - 1] = last
                    } else {
                        merged.append(segment)
                    }
                }

                for segment in merged {
                    let barRect = CGRect(
                        x: quoteBarX,
                        y: segment.top,
                        width: 3,
                        height: max(segment.bottom - segment.top, 12)
                    )
                    UIBezierPath(roundedRect: barRect, cornerRadius: 1.5).fill()
                }
            }

            context.restoreGState()
        }
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = MarkdownTextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.isUserInteractionEnabled = isEditable
        textView.allowsEditingTextAttributes = false
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        textView.textContainerInset = UIEdgeInsets(
            top: Self.caretTopInset,
            left: 0,
            bottom: 0,
            right: 0
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
        textView.contentInsetAdjustmentBehavior = .never
        textView.adjustsFontForContentSizeCategory = true
        textView.keyboardDismissMode = isEditable ? .interactive : .none
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.attributedText = makeAttributedText(from: text)

        context.coordinator.textView = textView
        context.coordinator.lastSyncedMarkdown = normalizeLineEndings(text)
        context.coordinator.updateTypingAttributes(for: textView)
        context.coordinator.keepCaretAtTopIfNeeded(textView)
        textView.setNeedsDisplay()

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEditable
        uiView.isSelectable = isEditable
        uiView.isUserInteractionEnabled = isEditable
        uiView.keyboardDismissMode = isEditable ? .interactive : .none

        guard !context.coordinator.isEditing else {
            return
        }

        let normalizedExternal = normalizeLineEndings(text)
        guard normalizedExternal != context.coordinator.lastSyncedMarkdown else {
            return
        }

        context.coordinator.isApplyingProgrammaticChange = true
        uiView.attributedText = makeAttributedText(from: normalizedExternal)
        context.coordinator.isApplyingProgrammaticChange = false
        context.coordinator.lastSyncedMarkdown = normalizedExternal
        context.coordinator.updateTypingAttributes(for: uiView)
        context.coordinator.keepCaretAtTopIfNeeded(uiView)
        uiView.invalidateIntrinsicContentSize()
        uiView.setNeedsDisplay()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth: CGFloat
        if let width = proposal.width, width > 0 {
            targetWidth = width
        } else if uiView.bounds.width > 0 {
            targetWidth = uiView.bounds.width
        } else {
            return nil
        }

        let fittingSize = CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        let measured = uiView.sizeThatFits(fittingSize)
        return CGSize(width: targetWidth, height: max(minimumHeight, ceil(measured.height)))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func normalizeLineEndings(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private func makeAttributedText(from markdown: String) -> NSAttributedString {
        let normalizedMarkdown = normalizeLineEndings(markdown)
        let decodedMarkdown = ImportPayloadNormalizer.decodeEscapedControlSequencesDeterministically(normalizedMarkdown)
        let rendered = renderMarkdownForDisplay(decodedMarkdown)
        return normalizedDisplayStyle(rendered)
    }

    private func normalizedDisplayStyle(_ attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttributes(in: fullRange) { attributes, range, _ in
            var merged = attributes
            if merged[.font] == nil {
                merged[.font] = UIFont.systemFont(ofSize: Self.baseFontSize, weight: .regular)
            }
            if merged[.foregroundColor] == nil {
                merged[.foregroundColor] = Self.labelColor
            }
            mutable.setAttributes(merged, range: range)
        }

        if mutable.length == 0 {
            return NSAttributedString(string: "", attributes: Self.baseAttributes)
        }

        // 解析 markdown 后补齐引用标记属性，确保引用左侧灰条可绘制。
        var location = 0
        let source = mutable.string as NSString
        while location < source.length {
            let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
            defer { location = lineRange.location + lineRange.length }
            guard lineRange.length > 0 else { continue }

            let paragraph = mutable.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) as? NSParagraphStyle
            let firstIndent = paragraph?.firstLineHeadIndent ?? 0
            let headIndent = paragraph?.headIndent ?? 0
            if firstIndent >= 9, headIndent >= 9 {
                mutable.addAttribute(Self.quoteMarkerAttribute, value: true, range: lineRange)
            }
        }

        return mutable
    }

    private func renderMarkdownForDisplay(_ markdown: String) -> NSAttributedString {
        let lines = markdown.components(separatedBy: "\n")
        let tableLineIndexes = detectMarkdownTableLineIndexes(lines)
        let rendered = NSMutableAttributedString()

        var isInsideFence = false
        var isInsideQuote = false

        for (index, rawLine) in lines.enumerated() {
            var line = rawLine
            var lineAttributes = bodyAttributes()
            var allowsInlineMarkdown = true

            if isFencedCodeDelimiter(line) {
                isInsideFence.toggle()
                lineAttributes = fencedCodeDelimiterAttributes()
                allowsInlineMarkdown = false
                isInsideQuote = false
            } else if isInsideFence {
                lineAttributes = fencedCodeAttributes()
                allowsInlineMarkdown = false
            } else if tableLineIndexes.contains(index) {
                isInsideQuote = false
                if isMarkdownTableSeparatorLine(line) {
                    line = normalizedTableSeparatorLine(line)
                    lineAttributes = tableSeparatorAttributes()
                } else if isMarkdownTableHeaderLine(index, tableLineIndexes: tableLineIndexes) {
                    line = normalizedTableContentLine(line)
                    lineAttributes = tableHeaderAttributes()
                } else {
                    line = normalizedTableContentLine(line)
                    lineAttributes = tableRowAttributes()
                }
                allowsInlineMarkdown = false
            } else if let heading = parseHeading(line) {
                isInsideQuote = false
                line = heading.content
                lineAttributes = headingAttributes(level: heading.level)
            } else if let content = parseQuoteContent(line) {
                isInsideQuote = true
                line = content
                lineAttributes = quoteAttributes()
            } else if let content = parseUnorderedListContent(line) {
                isInsideQuote = false
                line = "• " + content
                lineAttributes = listAttributes()
            } else if let ordered = parseOrderedListContent(line) {
                isInsideQuote = false
                line = "\(ordered.prefix) " + ordered.content
                lineAttributes = listAttributes()
            } else if isInsideQuote {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    isInsideQuote = false
                } else {
                    lineAttributes = quoteAttributes()
                }
            }

            let lineAttributed = makeInlineAttributed(
                from: line,
                baseAttributes: lineAttributes,
                enableInlineMarkdown: allowsInlineMarkdown
            )
            rendered.append(lineAttributed)

            if index < lines.count - 1 {
                rendered.append(NSAttributedString(string: "\n", attributes: lineAttributes))
            }
        }

        return rendered
    }

    private func detectMarkdownTableLineIndexes(_ lines: [String]) -> Set<Int> {
        var indexes = Set<Int>()
        var index = 0

        while index + 1 < lines.count {
            let header = lines[index]
            let separator = lines[index + 1]

            guard isPotentialMarkdownTableRow(header),
                  isMarkdownTableSeparatorLine(separator) else {
                index += 1
                continue
            }

            indexes.insert(index)
            indexes.insert(index + 1)
            index += 2

            while index < lines.count, isPotentialMarkdownTableRow(lines[index]) {
                indexes.insert(index)
                index += 1
            }
        }

        return indexes
    }

    private func isPotentialMarkdownTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.contains("|"), !isFencedCodeDelimiter(trimmed) else { return false }
        return trimmed.filter { $0 == "|" }.count >= 2
    }

    private func isMarkdownTableSeparatorLine(_ line: String) -> Bool {
        let cells = parseTableCells(line)
        guard !cells.isEmpty else { return false }

        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }

            var dashCount = 0
            for ch in trimmed {
                if ch == ":" || ch == " " || ch == "\t" {
                    continue
                }
                if isMarkdownDashCharacter(ch) {
                    dashCount += 1
                    continue
                }
                return false
            }
            return dashCount >= 2
        }
    }

    private func parseTableCells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        guard text.contains("|") else { return [] }

        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") { text.removeLast() }

        return text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    }

    private func isMarkdownDashCharacter(_ ch: Character) -> Bool {
        ch == "-" || ch == "—" || ch == "–" || ch == "－" || ch == "─" || ch == "_"
    }

    private func normalizedTableSeparatorLine(_ line: String) -> String {
        let cells = parseTableCells(line)
        guard !cells.isEmpty else {
            return String(line.map { isMarkdownDashCharacter($0) ? "-" : $0 })
        }

        let normalizedCells = cells.map(normalizedTableSeparatorCell)
        return "| " + normalizedCells.joined(separator: " | ") + " |"
    }

    private func normalizedTableContentLine(_ line: String) -> String {
        let cells = parseTableCells(line)
        guard !cells.isEmpty else { return line }

        let normalizedCells = cells.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "| " + normalizedCells.joined(separator: " | ") + " |"
    }

    private func normalizedTableSeparatorCell(_ cell: String) -> String {
        let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "---"
        }

        let leftAligned = trimmed.hasPrefix(":")
        let rightAligned = trimmed.hasSuffix(":")
        let dashCount = trimmed.reduce(into: 0) { count, ch in
            if isMarkdownDashCharacter(ch) {
                count += 1
            }
        }
        let body = String(repeating: "-", count: max(3, dashCount))

        if leftAligned && rightAligned {
            return ":\(body):"
        }
        if leftAligned {
            return ":\(body)"
        }
        if rightAligned {
            return "\(body):"
        }
        return body
    }

    private func isMarkdownTableHeaderLine(_ index: Int, tableLineIndexes: Set<Int>) -> Bool {
        tableLineIndexes.contains(index) && !tableLineIndexes.contains(index - 1)
    }

    private func isFencedCodeDelimiter(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
    }

    private func parseHeading(_ line: String) -> (level: Int, content: String)? {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLeading.hasPrefix("#") else { return nil }

        var level = 0
        var cursor = trimmedLeading.startIndex
        while cursor < trimmedLeading.endIndex, trimmedLeading[cursor] == "#", level < 6 {
            level += 1
            cursor = trimmedLeading.index(after: cursor)
        }
        guard level > 0, cursor < trimmedLeading.endIndex, trimmedLeading[cursor].isWhitespace else {
            return nil
        }

        while cursor < trimmedLeading.endIndex, trimmedLeading[cursor].isWhitespace {
            cursor = trimmedLeading.index(after: cursor)
        }
        let content = String(trimmedLeading[cursor...])
        return (level, content)
    }

    private func parseQuoteContent(_ line: String) -> String? {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLeading.hasPrefix(">") || trimmedLeading.hasPrefix("》") else {
            return nil
        }

        let markerRemoved = String(trimmedLeading.dropFirst())
        return markerRemoved.trimmingCharacters(in: .whitespaces)
    }

    private func parseUnorderedListContent(_ line: String) -> String? {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmedLeading.first,
              first == "-" || first == "*" || first == "+" else {
            return nil
        }

        let dropped = String(trimmedLeading.dropFirst())
        guard dropped.first?.isWhitespace == true else {
            return nil
        }
        return dropped.trimmingCharacters(in: .whitespaces)
    }

    private func parseOrderedListContent(_ line: String) -> (prefix: String, content: String)? {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard !trimmedLeading.isEmpty else { return nil }

        var digits = ""
        var cursor = trimmedLeading.startIndex
        while cursor < trimmedLeading.endIndex, trimmedLeading[cursor].isNumber {
            digits.append(trimmedLeading[cursor])
            cursor = trimmedLeading.index(after: cursor)
        }
        guard !digits.isEmpty,
              cursor < trimmedLeading.endIndex,
              trimmedLeading[cursor] == "." else {
            return nil
        }
        cursor = trimmedLeading.index(after: cursor)
        guard cursor < trimmedLeading.endIndex, trimmedLeading[cursor].isWhitespace else {
            return nil
        }
        while cursor < trimmedLeading.endIndex, trimmedLeading[cursor].isWhitespace {
            cursor = trimmedLeading.index(after: cursor)
        }

        return ("\(digits).", String(trimmedLeading[cursor...]))
    }

    private func makeInlineAttributed(
        from text: String,
        baseAttributes: [NSAttributedString.Key: Any],
        enableInlineMarkdown: Bool
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: text, attributes: baseAttributes)
        guard enableInlineMarkdown, !text.isEmpty else {
            return mutable
        }

        applyInlinePattern(
            pattern: "\\*\\*\\*([^*\\n]+)\\*\\*\\*",
            to: mutable,
            attributes: inlineAttributes(base: baseAttributes, bold: true, italic: true)
        )
        applyInlinePattern(
            pattern: "\\*\\*([^*\\n]+)\\*\\*",
            to: mutable,
            attributes: inlineAttributes(base: baseAttributes, bold: true)
        )
        applyInlinePattern(
            pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)",
            to: mutable,
            attributes: inlineAttributes(base: baseAttributes, italic: true)
        )
        applyInlinePattern(
            pattern: "(?<!_)_([^_\\n]+)_(?!_)",
            to: mutable,
            attributes: inlineAttributes(base: baseAttributes, italic: true)
        )
        applyInlinePattern(
            pattern: "~~([^~\\n]+)~~",
            to: mutable,
            attributes: inlineAttributes(base: baseAttributes, strikethrough: true)
        )
        applyInlinePattern(
            pattern: "`([^`\\n]+)`",
            to: mutable,
            attributes: inlineAttributes(base: baseAttributes, inlineCode: true)
        )

        return mutable
    }

    private func applyInlinePattern(
        pattern: String,
        to mutable: NSMutableAttributedString,
        attributes: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        while true {
            let text = mutable.string as NSString
            let fullRange = NSRange(location: 0, length: text.length)
            guard let match = regex.firstMatch(in: mutable.string, options: [], range: fullRange),
                  match.numberOfRanges > 1 else {
                break
            }

            let whole = match.range(at: 0)
            let inner = match.range(at: 1)
            guard whole.location != NSNotFound, inner.location != NSNotFound else {
                break
            }

            let content = text.substring(with: inner)
            let replacement = NSAttributedString(string: content, attributes: attributes)
            mutable.replaceCharacters(in: whole, with: replacement)
        }
    }

    private func inlineAttributes(
        base: [NSAttributedString.Key: Any],
        bold: Bool = false,
        italic: Bool = false,
        strikethrough: Bool = false,
        inlineCode: Bool = false
    ) -> [NSAttributedString.Key: Any] {
        var attributes = base
        let baseFont = (base[.font] as? UIFont)
            ?? UIFont.systemFont(ofSize: Self.baseFontSize, weight: .regular)
        let targetSize = baseFont.pointSize

        let font: UIFont
        if inlineCode {
            font = UIFont.monospacedSystemFont(ofSize: max(13, targetSize - 1), weight: .regular)
        } else if bold && italic {
            let boldBase = UIFont.systemFont(ofSize: targetSize, weight: .bold)
            let descriptor = boldBase.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])
                ?? boldBase.fontDescriptor
            font = UIFont(descriptor: descriptor, size: targetSize)
        } else if bold {
            font = UIFont.systemFont(ofSize: targetSize, weight: .bold)
        } else if italic {
            font = UIFont.italicSystemFont(ofSize: targetSize)
        } else {
            font = baseFont
        }

        attributes[.font] = font
        if attributes[.foregroundColor] == nil {
            attributes[.foregroundColor] = Self.labelColor
        }
        if strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        } else {
            attributes.removeValue(forKey: .strikethroughStyle)
        }
        if inlineCode {
            attributes[.backgroundColor] = UIColor.systemGray6
        }

        return attributes
    }

    private func bodyAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.2
        paragraph.paragraphSpacing = 6

        return [
            .font: UIFont.systemFont(ofSize: Self.baseFontSize, weight: .regular),
            .foregroundColor: Self.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let clamped = max(1, min(6, level))
        let size: CGFloat
        let lineSpacing: CGFloat
        let paragraphSpacing: CGFloat
        let paragraphSpacingBefore: CGFloat

        switch clamped {
        case 1:
            size = 30
            lineSpacing = 8
            paragraphSpacing = 12
            paragraphSpacingBefore = 5
        case 2:
            size = 26
            lineSpacing = 7
            paragraphSpacing = 10
            paragraphSpacingBefore = 4
        case 3:
            size = 22
            lineSpacing = 6
            paragraphSpacing = 8
            paragraphSpacingBefore = 3
        case 4:
            size = 20
            lineSpacing = 4.5
            paragraphSpacing = 7
            paragraphSpacingBefore = 2
        case 5:
            size = 18
            lineSpacing = 3.5
            paragraphSpacing = 6
            paragraphSpacingBefore = 1.5
        default:
            size = 17
            lineSpacing = 3
            paragraphSpacing = 5
            paragraphSpacingBefore = 1
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = paragraphSpacing
        paragraph.paragraphSpacingBefore = paragraphSpacingBefore

        return [
            .font: UIFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: Self.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func listAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 0
        paragraph.headIndent = 16
        paragraph.paragraphSpacing = 4
        paragraph.lineSpacing = 1.5

        return [
            .font: UIFont.systemFont(ofSize: Self.baseFontSize, weight: .regular),
            .foregroundColor: Self.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private func quoteAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 10
        paragraph.headIndent = 10
        paragraph.lineSpacing = 1.8

        return [
            .font: UIFont.systemFont(ofSize: Self.baseFontSize, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph,
            Self.quoteMarkerAttribute: true
        ]
    }

    private func tableHeaderAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 4
        paragraph.firstLineHeadIndent = 4
        paragraph.headIndent = 4

        return [
            .font: UIFont.monospacedSystemFont(ofSize: 14.5, weight: .semibold),
            .foregroundColor: Self.labelColor,
            .backgroundColor: UIColor.systemTeal.withAlphaComponent(0.16),
            .paragraphStyle: paragraph,
            Self.tableLineAttribute: true
        ]
    }

    private func tableRowAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 2
        paragraph.firstLineHeadIndent = 4
        paragraph.headIndent = 4

        return [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: Self.labelColor,
            .backgroundColor: UIColor.systemTeal.withAlphaComponent(0.09),
            .paragraphStyle: paragraph,
            Self.tableLineAttribute: true
        ]
    }

    private func tableSeparatorAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1
        paragraph.paragraphSpacing = 2
        paragraph.firstLineHeadIndent = 4
        paragraph.headIndent = 4

        return [
            .font: UIFont.monospacedSystemFont(ofSize: 13.5, weight: .medium),
            .foregroundColor: UIColor.tertiaryLabel,
            .backgroundColor: UIColor.systemTeal.withAlphaComponent(0.07),
            .paragraphStyle: paragraph,
            Self.tableLineAttribute: true
        ]
    }

    private func fencedCodeAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.firstLineHeadIndent = 2
        paragraph.headIndent = 2

        return [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: Self.labelColor,
            .backgroundColor: UIColor.systemGray6,
            .paragraphStyle: paragraph
        ]
    }

    private func fencedCodeDelimiterAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1

        return [
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NotionLikeTextEditor

        var isEditing = false
        var isApplyingProgrammaticChange = false
        var lastSyncedMarkdown = ""
        weak var textView: UITextView?

        private var pendingTypingAttributes: [NSAttributedString.Key: Any]?
        private var pendingTypingLineLocation: Int?
        private var pendingManualLineBreakLocation: Int?

        private enum BlockStyleKind: Equatable {
            case body
            case heading(level: Int)
            case quote
            case list
        }

        init(_ parent: NotionLikeTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            updateTypingAttributes(for: textView)
            keepCaretAtTopIfNeeded(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            syncToModel(textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if tryHandleBackspaceAtLineStart(in: textView, range: range, replacementText: text) {
                pendingManualLineBreakLocation = nil
                return false
            }
            if tryApplyPrefixShortcutIfNeeded(in: textView, range: range, replacementText: text) {
                return false
            }
            if text == "\n", range.length == 0 {
                pendingManualLineBreakLocation = range.location
            } else {
                pendingManualLineBreakLocation = nil
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else {
                return
            }

            applyLiveMarkdownTransforms(in: textView)
            normalizeNewLineStyleIfNeeded(in: textView)
            updateTypingAttributes(for: textView)
            keepCaretAtTopIfNeeded(textView)
            syncToModel(textView)
            textView.invalidateIntrinsicContentSize()
            textView.setNeedsDisplay()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else {
                return
            }

            updateTypingAttributes(for: textView)
            keepCaretAtTopIfNeeded(textView)
            textView.setNeedsDisplay()
        }

        func updateTypingAttributes(for textView: UITextView) {
            let storage = textView.textStorage
            let selection = textView.selectedRange
            let lineRange = currentLineContentRange(in: storage, cursor: selection.location)

            if lineRange.length == 0,
               let pendingTypingAttributes,
               pendingTypingLineLocation == lineRange.location {
                applyTypingAttributes(pendingTypingAttributes, to: textView)
                return
            }

            if pendingTypingLineLocation != lineRange.location {
                clearPendingTypingContext()
            }
            if lineRange.length > 0 {
                clearPendingTypingContext()
            }

            if lineRange.length == 0 {
                if let inherited = emptyLineTypingAttributes(in: storage, lineLocation: lineRange.location) {
                    applyTypingAttributes(inherited, to: textView)
                    return
                }
                applyTypingAttributes(NotionLikeTextEditor.baseAttributes, to: textView)
                return
            }

            guard storage.length > 0 else {
                applyTypingAttributes(NotionLikeTextEditor.baseAttributes, to: textView)
                return
            }

            var typing = NotionLikeTextEditor.baseAttributes

            if lineRange.length > 0 {
                let lineStart = lineRange.location
                let lineEnd = lineRange.location + lineRange.length
                let anchor: Int
                if selection.location > lineStart {
                    anchor = min(selection.location - 1, lineEnd - 1)
                } else {
                    anchor = lineStart
                }

                let inherited = storage.attributes(at: anchor, effectiveRange: nil)
                typing.merge(inherited) { _, new in new }
            } else if selection.location > 0 {
                let fallbackAnchor = min(selection.location - 1, storage.length - 1)
                let inherited = storage.attributes(at: fallbackAnchor, effectiveRange: nil)
                typing.merge(inherited) { _, new in new }
            }

            if typing[.foregroundColor] == nil {
                typing[.foregroundColor] = NotionLikeTextEditor.labelColor
            }
            applyTypingAttributes(typing, to: textView)
        }

        private func syncToModel(_ textView: UITextView) {
            let markdown = serializeMarkdown(from: textView.attributedText ?? NSAttributedString())
                .replacingOccurrences(of: "\r\n", with: "\n")

            guard markdown != lastSyncedMarkdown else {
                return
            }

            lastSyncedMarkdown = markdown
            parent.text = markdown
        }

        // 空文本时将光标固定在顶部，避免落在中线。
        func keepCaretAtTopIfNeeded(_ textView: UITextView) {
            guard textView.textStorage.length == 0 else {
                return
            }

            let lineLocation = currentLineContentRange(
                in: textView.textStorage,
                cursor: textView.selectedRange.location
            ).location
            if let pendingTypingAttributes,
               pendingTypingLineLocation == lineLocation {
                applyTypingAttributes(pendingTypingAttributes, to: textView)
            } else {
                applyTypingAttributes(NotionLikeTextEditor.baseAttributes, to: textView)
            }
            textView.textContainerInset = UIEdgeInsets(
                top: NotionLikeTextEditor.caretTopInset,
                left: 0,
                bottom: 0,
                right: 0
            )
            textView.contentInset = .zero
            textView.selectedRange = NSRange(location: 0, length: 0)
            textView.textContainer.layoutManager?.ensureLayout(for: textView.textContainer)
            textView.setContentOffset(
                CGPoint(
                    x: -textView.adjustedContentInset.left,
                    y: -textView.adjustedContentInset.top
                ),
                animated: false
            )
        }

        private func tryHandleBackspaceAtLineStart(
            in textView: UITextView,
            range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text.isEmpty,
                  range.length == 1,
                  textView.markedTextRange == nil else {
                return false
            }

            let storage = textView.textStorage
            guard storage.length > 0 else {
                return false
            }

            let source = storage.string as NSString
            guard range.location >= 0,
                  range.location < source.length,
                  isLineBreakCharacter(source.character(at: range.location)) else {
                return false
            }

            let cursor = range.location + range.length
            let lineRange = currentLineContentRange(in: storage, cursor: cursor)
            guard cursor == lineRange.location else {
                return false
            }

            let lineKind = blockStyleKind(in: storage, lineRange: lineRange)
            let pendingKind = blockStyleKind(from: pendingTypingAttributes ?? [:], lineText: nil)
            let hasSpecialPending = pendingTypingLineLocation == lineRange.location
                && pendingKind != .body

            let effectiveKind: BlockStyleKind
            if lineKind != .body {
                effectiveKind = lineKind
            } else if hasSpecialPending {
                effectiveKind = pendingKind
            } else {
                effectiveKind = .body
            }

            guard effectiveKind != .body else {
                return false
            }

            if effectiveKind == .quote,
               !shouldConvertQuoteLineToBodyOnBackspace(
                in: storage,
                lineRange: lineRange
               ) {
                return false
            }

            isApplyingProgrammaticChange = true
            storage.beginEditing()
            applyLineAttributes(
                in: storage,
                range: lineRange,
                attributes: NotionLikeTextEditor.baseAttributes
            )
            storage.endEditing()
            isApplyingProgrammaticChange = false

            clearPendingTypingContext()
            if lineRange.length == 0 {
                setPendingTypingContext(
                    attributes: NotionLikeTextEditor.baseAttributes,
                    lineLocation: lineRange.location
                )
            }

            textView.selectedRange = NSRange(location: lineRange.location, length: 0)
            applyTypingAttributes(NotionLikeTextEditor.baseAttributes, to: textView)
            syncToModel(textView)
            textView.invalidateIntrinsicContentSize()
            textView.setNeedsDisplay()
            return true
        }

        private func normalizeNewLineStyleIfNeeded(in textView: UITextView) {
            guard let breakLocation = pendingManualLineBreakLocation else {
                return
            }
            pendingManualLineBreakLocation = nil

            let storage = textView.textStorage
            guard breakLocation >= 0, breakLocation < storage.length else {
                return
            }

            let newLineCursor = min(breakLocation + 1, storage.length)
            let previousLineRange = currentLineContentRange(in: storage, cursor: breakLocation)
            let nextLineRange = currentLineContentRange(in: storage, cursor: newLineCursor)

            let sourceKind = splitSourceStyleKind(
                in: storage,
                breakLocation: breakLocation,
                previousLineRange: previousLineRange,
                nextLineRange: nextLineRange,
                fallbackTypingAttributes: textView.typingAttributes
            )
            let shouldInheritNextLine: Bool
            switch sourceKind {
            case .quote:
                shouldInheritNextLine = true
            case .heading, .list:
                shouldInheritNextLine = nextLineRange.length > 0
            case .body:
                shouldInheritNextLine = false
            }

            let breakKind: BlockStyleKind
            if previousLineRange.length > 0 {
                breakKind = blockStyleKind(in: storage, lineRange: previousLineRange)
            } else if sourceKind == .quote {
                breakKind = .quote
            } else {
                breakKind = .body
            }
            let nextKind: BlockStyleKind = shouldInheritNextLine ? sourceKind : .body

            isApplyingProgrammaticChange = true
            storage.beginEditing()
            applyAttributesToLineBreakIfNeeded(
                in: storage,
                at: breakLocation,
                attributes: attributes(for: breakKind)
            )
            applyLineAttributes(
                in: storage,
                range: nextLineRange,
                attributes: attributes(for: nextKind)
            )
            storage.endEditing()
            isApplyingProgrammaticChange = false

            if nextLineRange.length == 0 {
                setPendingTypingContext(
                    attributes: attributes(for: nextKind),
                    lineLocation: nextLineRange.location
                )
            } else {
                clearPendingTypingContext()
            }

            applyTypingAttributes(attributes(for: nextKind), to: textView)
            textView.selectedRange = NSRange(location: newLineCursor, length: 0)
            textView.setNeedsDisplay()
        }

        private func tryApplyPrefixShortcutIfNeeded(
            in textView: UITextView,
            range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == " ",
                  range.length == 0,
                  textView.markedTextRange == nil else {
                return false
            }

            let storage = textView.textStorage
            let lineRange = currentLineContentRange(in: storage, cursor: range.location)
            guard range.location >= lineRange.location else {
                return false
            }

            let prefixRange = NSRange(
                location: lineRange.location,
                length: range.location - lineRange.location
            )
            guard prefixRange.length > 0 else {
                return false
            }

            let prefixText = (storage.string as NSString).substring(with: prefixRange)

            if let match = prefixText.range(of: #"^(#{1,5})$"#, options: .regularExpression) {
                let marker = String(prefixText[match])
                let level = max(1, min(5, marker.filter { $0 == "#" }.count))
                let attrs = headingAttributes(level: level)
                applyImmediatePrefixShortcut(
                    in: textView,
                    replaceRange: prefixRange,
                    lineRange: lineRange,
                    attributes: attrs,
                    shouldKeepPendingWhenEmpty: true,
                    addPlaceholderWhenEmpty: true
                )
                return true
            }

            if prefixText.range(of: #"^(>|》)$"#, options: .regularExpression) != nil {
                let attrs = quoteAttributes()
                applyImmediatePrefixShortcut(
                    in: textView,
                    replaceRange: prefixRange,
                    lineRange: lineRange,
                    attributes: attrs,
                    shouldKeepPendingWhenEmpty: true,
                    addPlaceholderWhenEmpty: true
                )
                return true
            }

            return false
        }

        private func applyImmediatePrefixShortcut(
            in textView: UITextView,
            replaceRange: NSRange,
            lineRange: NSRange,
            attributes: [NSAttributedString.Key: Any],
            shouldKeepPendingWhenEmpty: Bool,
            addPlaceholderWhenEmpty: Bool
        ) {
            let storage = textView.textStorage
            let cursorBefore = replaceRange.location + replaceRange.length
            var cursor = cursorBefore

            isApplyingProgrammaticChange = true
            storage.beginEditing()
            storage.deleteCharacters(in: replaceRange)
            cursor = adjustCursorAfterReplacement(
                cursor: cursor,
                replacedRange: replaceRange,
                replacementLength: 0
            )
            let updatedRange = currentLineContentRange(in: storage, cursor: cursor)
            if updatedRange.length > 0 {
                applyLineAttributes(in: storage, range: updatedRange, attributes: attributes)
                clearPendingTypingContext()
            } else if shouldKeepPendingWhenEmpty {
                setPendingTypingContext(attributes: attributes, lineLocation: updatedRange.location)
                if addPlaceholderWhenEmpty {
                    applyPlaceholderAttributesForEmptyLine(
                        in: storage,
                        at: updatedRange.location,
                        attributes: attributes
                    )
                }
            }
            storage.endEditing()
            isApplyingProgrammaticChange = false

            textView.selectedRange = NSRange(location: max(0, min(cursor, storage.length)), length: 0)
            applyTypingAttributes(attributes, to: textView)
            updateTypingAttributes(for: textView)
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else {
                    return
                }
                self.applyTypingAttributes(attributes, to: textView)
            }
            syncToModel(textView)
            textView.invalidateIntrinsicContentSize()
            textView.setNeedsDisplay()
        }

        private func applyPlaceholderAttributesForEmptyLine(
            in storage: NSTextStorage,
            at lineLocation: Int,
            attributes: [NSAttributedString.Key: Any]
        ) {
            let source = storage.string as NSString
            guard lineLocation < source.length else {
                return
            }
            let code = source.character(at: lineLocation)
            guard code == 0x0A || code == 0x0D else {
                return
            }
            storage.addAttributes(attributes, range: NSRange(location: lineLocation, length: 1))
        }

        private func applyLiveMarkdownTransforms(in textView: UITextView) {
            let storage = textView.textStorage
            var cursor = textView.selectedRange.location

            isApplyingProgrammaticChange = true
            storage.beginEditing()

            applyPrefixTransform(in: storage, cursor: &cursor, textView: textView)

            applyInlineTransform(
                pattern: "\\*\\*\\*([^*\\n]+)\\*\\*\\*",
                attributes: styleAttributes(bold: true, italic: true),
                in: storage,
                cursor: &cursor
            )
            applyInlineTransform(
                pattern: "\\*\\*([^*\\n]+)\\*\\*",
                attributes: styleAttributes(bold: true),
                in: storage,
                cursor: &cursor
            )
            applyInlineTransform(
                pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)",
                attributes: styleAttributes(italic: true),
                in: storage,
                cursor: &cursor
            )
            applyInlineTransform(
                pattern: "(?<!_)_([^_\\n]+)_(?!_)",
                attributes: styleAttributes(italic: true),
                in: storage,
                cursor: &cursor
            )
            applyInlineTransform(
                pattern: "~~([^~\\n]+)~~",
                attributes: styleAttributes(strikethrough: true),
                in: storage,
                cursor: &cursor
            )
            applyInlineTransform(
                pattern: "`([^`\\n]+)`",
                attributes: styleAttributes(inlineCode: true),
                in: storage,
                cursor: &cursor
            )

            storage.endEditing()
            isApplyingProgrammaticChange = false
            textView.selectedRange = NSRange(
                location: max(0, min(cursor, storage.length)),
                length: 0
            )
        }

        private func applyPrefixTransform(
            in storage: NSTextStorage,
            cursor: inout Int,
            textView: UITextView
        ) {
            let lineRange = currentLineContentRange(in: storage, cursor: cursor)
            guard lineRange.length >= 2 else {
                return
            }

            let lineText = (storage.string as NSString).substring(with: lineRange)

            if let headingMatch = lineText.range(
                of: #"^(#{1,5})\s"#,
                options: .regularExpression
            ) {
                let headingMarker = String(lineText[headingMatch])
                let level = max(1, min(5, headingMarker.filter { $0 == "#" }.count))
                let markerLength = headingMarker.utf16.count
                let markerRange = NSRange(location: lineRange.location, length: markerLength)

                storage.deleteCharacters(in: markerRange)
                cursor = adjustCursorAfterReplacement(
                    cursor: cursor,
                    replacedRange: markerRange,
                    replacementLength: 0
                )

                let updatedRange = currentLineContentRange(in: storage, cursor: cursor)
                let headingStyle = headingAttributes(level: level)

                applyLineAttributes(in: storage, range: updatedRange, attributes: headingStyle)
                updatePendingTypingContext(
                    attributes: headingStyle,
                    lineLocation: updatedRange.location,
                    lineLength: updatedRange.length
                )
                applyTypingAttributes(headingStyle, to: textView)
                return
            }

            if let bulletRange = lineText.range(of: #"^[-*+]\s"#, options: .regularExpression) {
                let markerLength = lineText[bulletRange].utf16.count
                let markerRange = NSRange(location: lineRange.location, length: markerLength)
                let replacement = NSAttributedString(
                    string: "• ",
                    attributes: NotionLikeTextEditor.baseAttributes
                )

                storage.replaceCharacters(in: markerRange, with: replacement)
                cursor = adjustCursorAfterReplacement(
                    cursor: cursor,
                    replacedRange: markerRange,
                    replacementLength: replacement.length
                )

                let updatedRange = currentLineContentRange(in: storage, cursor: cursor)
                let listStyle = listAttributes()
                applyLineAttributes(in: storage, range: updatedRange, attributes: listStyle)
                updatePendingTypingContext(
                    attributes: listStyle,
                    lineLocation: updatedRange.location,
                    lineLength: updatedRange.length
                )
                return
            }

            if let quoteRange = lineText.range(
                of: #"^(>|》)\s"#,
                options: .regularExpression
            ) {
                let markerLength = lineText[quoteRange].utf16.count
                let markerRange = NSRange(location: lineRange.location, length: markerLength)

                storage.deleteCharacters(in: markerRange)
                cursor = adjustCursorAfterReplacement(
                    cursor: cursor,
                    replacedRange: markerRange,
                    replacementLength: 0
                )

                let updatedRange = currentLineContentRange(in: storage, cursor: cursor)
                let quoteStyle = quoteAttributes()
                applyLineAttributes(in: storage, range: updatedRange, attributes: quoteStyle)
                updatePendingTypingContext(
                    attributes: quoteStyle,
                    lineLocation: updatedRange.location,
                    lineLength: updatedRange.length
                )
                applyTypingAttributes(quoteStyle, to: textView)
            }
        }

        private func applyInlineTransform(
            pattern: String,
            attributes: [NSAttributedString.Key: Any],
            in storage: NSTextStorage,
            cursor: inout Int
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return
            }

            while true {
                let lineRange = currentLineContentRange(in: storage, cursor: cursor)
                guard lineRange.length > 0 else {
                    return
                }

                let lineText = (storage.string as NSString).substring(with: lineRange)
                let searchRange = NSRange(location: 0, length: (lineText as NSString).length)
                guard let match = regex.firstMatch(in: lineText, range: searchRange) else {
                    return
                }

                let fullRange = NSRange(
                    location: lineRange.location + match.range.location,
                    length: match.range.length
                )
                let contentRange = NSRange(
                    location: lineRange.location + match.range(at: 1).location,
                    length: match.range(at: 1).length
                )
                let content = (storage.string as NSString).substring(with: contentRange)

                let mergedAttributes = mergedInlineAttributes(
                    in: storage,
                    at: contentRange.location,
                    inlineAttributes: attributes
                )
                let replacement = NSAttributedString(string: content, attributes: mergedAttributes)
                storage.replaceCharacters(in: fullRange, with: replacement)

                cursor = adjustCursorAfterReplacement(
                    cursor: cursor,
                    replacedRange: fullRange,
                    replacementLength: replacement.length
                )
            }
        }

        private func mergedInlineAttributes(
            in storage: NSTextStorage,
            at location: Int,
            inlineAttributes: [NSAttributedString.Key: Any]
        ) -> [NSAttributedString.Key: Any] {
            guard storage.length > 0 else {
                return inlineAttributes
            }

            let probe = max(0, min(location, storage.length - 1))
            var merged = inlineAttributes

            if let paragraph = storage.attribute(.paragraphStyle, at: probe, effectiveRange: nil) {
                merged[.paragraphStyle] = paragraph
            }
            if let quoteMarker = storage.attribute(
                NotionLikeTextEditor.quoteMarkerAttribute,
                at: probe,
                effectiveRange: nil
            ) {
                merged[NotionLikeTextEditor.quoteMarkerAttribute] = quoteMarker
            }
            if let tableMarker = storage.attribute(
                NotionLikeTextEditor.tableLineAttribute,
                at: probe,
                effectiveRange: nil
            ) {
                merged[NotionLikeTextEditor.tableLineAttribute] = tableMarker
            }

            return merged
        }

        // 基于当前光标定位当前行，保证前缀渲染只影响本行。
        private func currentLineContentRange(in storage: NSTextStorage, cursor: Int) -> NSRange {
            let source = storage.string as NSString
            guard source.length > 0 else {
                return NSRange(location: 0, length: 0)
            }

            let safeCursor = max(0, min(cursor, source.length))
            var lineStart = safeCursor

            while lineStart > 0 {
                let prevIndex = lineStart - 1
                let code = source.character(at: prevIndex)
                if code == 0x0A || code == 0x0D {
                    break
                }
                lineStart -= 1
            }

            var lineEnd = safeCursor
            while lineEnd < source.length {
                let code = source.character(at: lineEnd)
                if code == 0x0A || code == 0x0D {
                    break
                }
                lineEnd += 1
            }

            return NSRange(location: lineStart, length: lineEnd - lineStart)
        }

        private func adjustCursorAfterReplacement(
            cursor: Int,
            replacedRange: NSRange,
            replacementLength: Int
        ) -> Int {
            let replacedEnd = replacedRange.location + replacedRange.length
            let replacementEnd = replacedRange.location + replacementLength

            if cursor < replacedRange.location {
                return cursor
            }
            if cursor >= replacedEnd {
                return cursor + replacementLength - replacedRange.length
            }

            return replacementEnd
        }

        private func splitSourceStyleKind(
            in storage: NSTextStorage,
            breakLocation: Int,
            previousLineRange: NSRange,
            nextLineRange: NSRange,
            fallbackTypingAttributes: [NSAttributedString.Key: Any]
        ) -> BlockStyleKind {
            let source = storage.string as NSString

            if nextLineRange.length > 0,
               nextLineRange.location < source.length {
                let attrs = storage.attributes(at: nextLineRange.location, effectiveRange: nil)
                let lineText = source.substring(with: nextLineRange)
                let kind = blockStyleKind(from: attrs, lineText: lineText)
                if kind != .body {
                    return kind
                }
            }

            if previousLineRange.length > 0,
               previousLineRange.location < source.length {
                let attrs = storage.attributes(at: previousLineRange.location, effectiveRange: nil)
                let lineText = source.substring(with: previousLineRange)
                let kind = blockStyleKind(from: attrs, lineText: lineText)
                if kind != .body {
                    return kind
                }
            }

            if let pendingTypingAttributes,
               pendingTypingLineLocation == previousLineRange.location
                || pendingTypingLineLocation == nextLineRange.location {
                let kind = blockStyleKind(from: pendingTypingAttributes, lineText: nil)
                if kind != .body {
                    return kind
                }
            }

            if breakLocation > 0, breakLocation <= source.length {
                let previousCharIndex = breakLocation - 1
                if previousCharIndex < source.length,
                   !isLineBreakCharacter(source.character(at: previousCharIndex)) {
                    let attrs = storage.attributes(at: previousCharIndex, effectiveRange: nil)
                    let kind = blockStyleKind(from: attrs, lineText: nil)
                    if kind != .body {
                        return kind
                    }
                }
            }

            return blockStyleKind(from: fallbackTypingAttributes, lineText: nil)
        }

        private func emptyLineTypingAttributes(
            in storage: NSTextStorage,
            lineLocation: Int
        ) -> [NSAttributedString.Key: Any]? {
            let source = storage.string as NSString
            guard lineLocation >= 0,
                  lineLocation < source.length,
                  isLineBreakCharacter(source.character(at: lineLocation)) else {
                return nil
            }

            let attrs = storage.attributes(at: lineLocation, effectiveRange: nil)
            let kind = blockStyleKind(from: attrs, lineText: nil)
            guard kind != .body else {
                return nil
            }
            return attributes(for: kind)
        }

        private func blockStyleKind(
            in storage: NSTextStorage,
            lineRange: NSRange
        ) -> BlockStyleKind {
            let source = storage.string as NSString
            guard source.length > 0 else {
                if let pendingTypingAttributes,
                   pendingTypingLineLocation == lineRange.location {
                    return blockStyleKind(from: pendingTypingAttributes, lineText: nil)
                }
                return .body
            }

            if lineRange.length > 0, lineRange.location < source.length {
                let attrs = storage.attributes(at: lineRange.location, effectiveRange: nil)
                let lineText = source.substring(with: lineRange)
                return blockStyleKind(from: attrs, lineText: lineText)
            }

            if lineRange.location < source.length {
                let attrs = storage.attributes(at: lineRange.location, effectiveRange: nil)
                return blockStyleKind(from: attrs, lineText: nil)
            }

            if let pendingTypingAttributes,
               pendingTypingLineLocation == lineRange.location {
                return blockStyleKind(from: pendingTypingAttributes, lineText: nil)
            }

            return .body
        }

        private func blockStyleKind(
            from attributes: [NSAttributedString.Key: Any],
            lineText: String?
        ) -> BlockStyleKind {
            if isQuoteAttributes(attributes) {
                return .quote
            }

            if let font = attributes[.font] as? UIFont,
               let level = headingLevel(for: font) {
                return .heading(level: level)
            }

            if isListAttributes(attributes: attributes, lineText: lineText) {
                return .list
            }

            return .body
        }

        private func attributes(for kind: BlockStyleKind) -> [NSAttributedString.Key: Any] {
            switch kind {
            case .body:
                return NotionLikeTextEditor.baseAttributes
            case .heading(let level):
                return headingAttributes(level: level)
            case .quote:
                return quoteAttributes()
            case .list:
                return listAttributes()
            }
        }

        private func isQuoteAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
            if (attributes[NotionLikeTextEditor.quoteMarkerAttribute] as? Bool) == true {
                return true
            }

            guard let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle else {
                return false
            }
            return paragraph.firstLineHeadIndent >= 9 && paragraph.headIndent >= 9
        }

        private func isListAttributes(
            attributes: [NSAttributedString.Key: Any],
            lineText: String?
        ) -> Bool {
            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle,
               paragraph.headIndent >= 14,
               paragraph.firstLineHeadIndent < 10 {
                return true
            }

            guard let lineText else {
                return false
            }
            return lineText.hasPrefix("• ")
                || lineText.hasPrefix("•\t")
                || lineText.hasPrefix("◦ ")
                || lineText.hasPrefix("◦\t")
        }

        private func headingLevel(for font: UIFont) -> Int? {
            let size = font.pointSize
            guard size > 17 else {
                return nil
            }

            if size >= 28 { return 1 }
            if size >= 24 { return 2 }
            if size >= 21 { return 3 }
            if size >= 19 { return 4 }
            return 5
        }

        private func isLineBreakCharacter(_ code: UInt16) -> Bool {
            code == 0x0A || code == 0x0D
        }

        private func shouldConvertQuoteLineToBodyOnBackspace(
            in storage: NSTextStorage,
            lineRange: NSRange
        ) -> Bool {
            let hasPreviousQuoteLine = previousLineContentRange(in: storage, lineStart: lineRange.location)
                .map { isQuoteLine(in: storage, lineRange: $0) } ?? false
            let hasNextQuoteLine = nextLineContentRange(in: storage, lineRange: lineRange)
                .map { isQuoteLine(in: storage, lineRange: $0) } ?? false

            // 仅当当前引用块已经只剩这一行时，行首退格才降级为正文。
            return !hasPreviousQuoteLine && !hasNextQuoteLine
        }

        private func previousLineContentRange(
            in storage: NSTextStorage,
            lineStart: Int
        ) -> NSRange? {
            let source = storage.string as NSString
            guard source.length > 0, lineStart > 0 else {
                return nil
            }

            let breakIndex = lineStart - 1
            guard breakIndex < source.length,
                  isLineBreakCharacter(source.character(at: breakIndex)) else {
                return nil
            }

            var previousStart = breakIndex
            while previousStart > 0 {
                let code = source.character(at: previousStart - 1)
                if isLineBreakCharacter(code) {
                    break
                }
                previousStart -= 1
            }

            return NSRange(location: previousStart, length: breakIndex - previousStart)
        }

        private func nextLineContentRange(
            in storage: NSTextStorage,
            lineRange: NSRange
        ) -> NSRange? {
            let source = storage.string as NSString
            guard source.length > 0 else {
                return nil
            }

            let currentEnd = lineRange.location + lineRange.length
            guard currentEnd < source.length,
                  isLineBreakCharacter(source.character(at: currentEnd)) else {
                return nil
            }

            let nextStart = currentEnd + 1
            guard nextStart <= source.length else {
                return nil
            }

            var nextEnd = nextStart
            while nextEnd < source.length {
                let code = source.character(at: nextEnd)
                if isLineBreakCharacter(code) {
                    break
                }
                nextEnd += 1
            }

            return NSRange(location: nextStart, length: nextEnd - nextStart)
        }

        private func isQuoteLine(in storage: NSTextStorage, lineRange: NSRange) -> Bool {
            let source = storage.string as NSString

            if lineRange.length > 0,
               lineRange.location < source.length {
                let attrs = storage.attributes(at: lineRange.location, effectiveRange: nil)
                return isQuoteAttributes(attrs)
            }

            if lineRange.location < source.length,
               isLineBreakCharacter(source.character(at: lineRange.location)) {
                let attrs = storage.attributes(at: lineRange.location, effectiveRange: nil)
                return isQuoteAttributes(attrs)
            }

            return false
        }

        private func lineRangeIncludingLineBreak(
            in storage: NSTextStorage,
            lineRange: NSRange
        ) -> NSRange {
            let source = storage.string as NSString
            guard source.length > 0 else {
                return lineRange
            }

            var targetRange = lineRange

            if lineRange.length == 0 {
                if lineRange.location < source.length,
                   isLineBreakCharacter(source.character(at: lineRange.location)) {
                    targetRange.length = 1
                }
                return targetRange
            }

            let lineEnd = lineRange.location + lineRange.length
            if lineEnd < source.length,
               isLineBreakCharacter(source.character(at: lineEnd)) {
                targetRange.length += 1
            }
            return targetRange
        }

        private func applyAttributesToLineBreakIfNeeded(
            in storage: NSTextStorage,
            at location: Int,
            attributes: [NSAttributedString.Key: Any]
        ) {
            let source = storage.string as NSString
            guard location >= 0,
                  location < source.length,
                  isLineBreakCharacter(source.character(at: location)) else {
                return
            }

            let range = NSRange(location: location, length: 1)
            storage.removeAttribute(.paragraphStyle, range: range)
            storage.removeAttribute(NotionLikeTextEditor.quoteMarkerAttribute, range: range)
            storage.addAttributes(attributes, range: range)
        }

        private func applyLineAttributes(
            in storage: NSTextStorage,
            range: NSRange,
            attributes: [NSAttributedString.Key: Any]
        ) {
            let targetRange = lineRangeIncludingLineBreak(in: storage, lineRange: range)
            guard targetRange.length > 0 else {
                return
            }
            storage.removeAttribute(.paragraphStyle, range: targetRange)
            storage.removeAttribute(NotionLikeTextEditor.quoteMarkerAttribute, range: targetRange)
            storage.addAttributes(attributes, range: targetRange)
        }

        private func setPendingTypingContext(
            attributes: [NSAttributedString.Key: Any],
            lineLocation: Int
        ) {
            pendingTypingAttributes = attributes
            pendingTypingLineLocation = lineLocation
        }

        private func updatePendingTypingContext(
            attributes: [NSAttributedString.Key: Any],
            lineLocation: Int,
            lineLength: Int
        ) {
            if lineLength == 0 {
                setPendingTypingContext(attributes: attributes, lineLocation: lineLocation)
            } else {
                clearPendingTypingContext()
            }
        }

        private func clearPendingTypingContext() {
            pendingTypingAttributes = nil
            pendingTypingLineLocation = nil
        }

        private func applyTypingAttributes(
            _ attributes: [NSAttributedString.Key: Any],
            to textView: UITextView
        ) {
            var merged = NotionLikeTextEditor.baseAttributes
            merged.merge(attributes) { _, new in new }
            if merged[.foregroundColor] == nil {
                merged[.foregroundColor] = NotionLikeTextEditor.labelColor
            }

            let font = (merged[.font] as? UIFont)
                ?? UIFont.systemFont(ofSize: NotionLikeTextEditor.baseFontSize, weight: .regular)
            merged[.font] = font

            textView.typingAttributes = merged

            // 光标高度跟随 UITextView.font；这里同步可确保标题/正文切换即时生效。
            if textView.font !== font {
                textView.font = font
            }
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            textView.setNeedsDisplay()
        }

        private func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
            let clamped = min(5, max(1, level))
            let size: CGFloat
            let lineSpacing: CGFloat
            let paragraphSpacing: CGFloat
            let paragraphSpacingBefore: CGFloat

            switch clamped {
            case 1:
                size = 30
                lineSpacing = 8
                paragraphSpacing = 12
                paragraphSpacingBefore = 5
            case 2:
                size = 26
                lineSpacing = 7
                paragraphSpacing = 10
                paragraphSpacingBefore = 4
            case 3:
                size = 22
                lineSpacing = 6
                paragraphSpacing = 8
                paragraphSpacingBefore = 3
            case 4:
                size = 20
                lineSpacing = 4.5
                paragraphSpacing = 7
                paragraphSpacingBefore = 2
            case 5:
                size = 18
                lineSpacing = 3.5
                paragraphSpacing = 6
                paragraphSpacingBefore = 1.5
            default:
                size = 18
                lineSpacing = 3.5
                paragraphSpacing = 6
                paragraphSpacingBefore = 1.5
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = lineSpacing
            paragraph.paragraphSpacing = paragraphSpacing
            paragraph.paragraphSpacingBefore = paragraphSpacingBefore

            return [
                .font: UIFont.systemFont(ofSize: size, weight: .bold),
                .foregroundColor: NotionLikeTextEditor.labelColor,
                .paragraphStyle: paragraph
            ]
        }

        private func listAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = 16
            paragraph.paragraphSpacing = 4
            paragraph.lineSpacing = 1.5

            return [
                .font: UIFont.systemFont(
                    ofSize: NotionLikeTextEditor.baseFontSize,
                    weight: .regular
                ),
                .foregroundColor: NotionLikeTextEditor.labelColor,
                .paragraphStyle: paragraph
            ]
        }

        private func quoteAttributes() -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = 10
            paragraph.headIndent = 10
            paragraph.lineSpacing = 1.8

            return [
                .font: UIFont.systemFont(
                    ofSize: NotionLikeTextEditor.baseFontSize,
                    weight: .regular
                ),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph,
                NotionLikeTextEditor.quoteMarkerAttribute: true
            ]
        }

        private func styleAttributes(
            bold: Bool = false,
            italic: Bool = false,
            strikethrough: Bool = false,
            inlineCode: Bool = false
        ) -> [NSAttributedString.Key: Any] {
            let font: UIFont

            if inlineCode {
                font = UIFont.monospacedSystemFont(
                    ofSize: max(13, NotionLikeTextEditor.baseFontSize - 1),
                    weight: .regular
                )
            } else {
                font = makeFont(bold: bold, italic: italic)
            }

            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NotionLikeTextEditor.labelColor
            ]

            if strikethrough {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if inlineCode {
                attributes[.backgroundColor] = UIColor.systemGray6
            }

            return attributes
        }

        private func makeFont(bold: Bool, italic: Bool) -> UIFont {
            if bold && italic {
                let base = UIFont.systemFont(
                    ofSize: NotionLikeTextEditor.baseFontSize,
                    weight: .bold
                )
                let descriptor = base.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])
                    ?? base.fontDescriptor
                return UIFont(descriptor: descriptor, size: NotionLikeTextEditor.baseFontSize)
            }
            if bold {
                return UIFont.systemFont(
                    ofSize: NotionLikeTextEditor.baseFontSize,
                    weight: .bold
                )
            }
            if italic {
                return UIFont.italicSystemFont(ofSize: NotionLikeTextEditor.baseFontSize)
            }
            return UIFont.systemFont(
                ofSize: NotionLikeTextEditor.baseFontSize,
                weight: .regular
            )
        }

        private func serializeMarkdown(from attributedText: NSAttributedString) -> String {
            let source = attributedText.string as NSString
            guard source.length > 0 else {
                return ""
            }

            var lines: [String] = []
            var location = 0

            while location < source.length {
                let rawLineRange = source.lineRange(for: NSRange(location: location, length: 0))
                var contentRange = rawLineRange

                if contentRange.length > 0 {
                    let tail = NSRange(
                        location: contentRange.location + contentRange.length - 1,
                        length: 1
                    )
                    if source.substring(with: tail) == "\n" {
                        contentRange.length -= 1
                    }
                }

                let line = attributedText.attributedSubstring(from: contentRange)
                lines.append(serializeLine(line))
                location = rawLineRange.location + rawLineRange.length
            }

            return lines.joined(separator: "\n")
        }

        private func serializeLine(_ line: NSAttributedString) -> String {
            guard line.length > 0 else {
                return ""
            }

            if hasTableStyle(in: line) {
                return line.string
            }

            var prefix = ""
            let mutableLine = NSMutableAttributedString(attributedString: line)

            if let headingLevel = detectHeadingLevel(in: line) {
                prefix = String(repeating: "#", count: headingLevel) + " "
            } else if let listPrefix = detectListPrefix(in: line.string),
                      mutableLine.length >= listPrefix.removeLength {
                prefix = listPrefix.markdown
                mutableLine.deleteCharacters(
                    in: NSRange(location: 0, length: listPrefix.removeLength)
                )
            } else if hasQuoteStyle(in: line) {
                prefix = "> "
            }

            let fullRange = NSRange(location: 0, length: mutableLine.length)
            var output = ""

            mutableLine.enumerateAttributes(in: fullRange) { attributes, range, _ in
                let fragment = mutableLine.attributedSubstring(from: range).string
                guard !fragment.isEmpty else {
                    return
                }
                output += markdownForRun(text: fragment, attributes: attributes)
            }

            return prefix + output
        }

        private func markdownForRun(
            text: String,
            attributes: [NSAttributedString.Key: Any]
        ) -> String {
            let leading = String(text.prefix { $0.isWhitespace })
            let trailing = String(text.reversed().prefix { $0.isWhitespace }.reversed())
            let coreStart = text.index(text.startIndex, offsetBy: leading.count)
            let coreEnd = text.index(text.endIndex, offsetBy: -trailing.count)

            guard coreStart < coreEnd else {
                return text
            }

            var core = String(text[coreStart..<coreEnd])
            guard !core.isEmpty else {
                return text
            }

            let font = attributes[.font] as? UIFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let isBold = traits.contains(.traitBold)
            let isItalic = traits.contains(.traitItalic)
            let isCode = traits.contains(.traitMonoSpace)
            let isStrike = (attributes[.strikethroughStyle] as? Int ?? 0) != 0

            if isCode {
                core = "`\(core)`"
            } else if isBold && isItalic {
                core = "***\(core)***"
            } else if isBold {
                core = "**\(core)**"
            } else if isItalic {
                core = "*\(core)*"
            }

            if isStrike {
                core = "~~\(core)~~"
            }

            return leading + core + trailing
        }

        private func detectHeadingLevel(in line: NSAttributedString) -> Int? {
            let nsLine = line.string as NSString
            let trimmed = line.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            var firstContentIndex: Int?
            for index in 0..<nsLine.length {
                let scalar = nsLine.substring(with: NSRange(location: index, length: 1))
                if scalar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                firstContentIndex = index
                break
            }

            guard let firstContentIndex else {
                return nil
            }

            let font = line.attribute(.font, at: firstContentIndex, effectiveRange: nil) as? UIFont
            let size = font?.pointSize ?? 0
            guard size > 17 else {
                return nil
            }

            if size >= 28 { return 1 }
            if size >= 24 { return 2 }
            if size >= 21 { return 3 }
            if size >= 19 { return 4 }
            return 5
        }

        private func detectListPrefix(in line: String) -> (markdown: String, removeLength: Int)? {
            let candidates: [(String, String)] = [
                ("•\t", "- "),
                ("• ", "- "),
                ("◦\t", "- "),
                ("◦ ", "- "),
                ("- ", "- "),
                ("* ", "- ")
            ]

            for (token, markdown) in candidates where line.hasPrefix(token) {
                return (markdown, token.utf16.count)
            }

            return nil
        }

        private func hasQuoteStyle(in line: NSAttributedString) -> Bool {
            guard line.length > 0 else {
                return false
            }

            let paragraph = line.attribute(
                .paragraphStyle,
                at: 0,
                effectiveRange: nil
            ) as? NSParagraphStyle

            return (paragraph?.headIndent ?? 0) >= 10
        }

        private func hasTableStyle(in line: NSAttributedString) -> Bool {
            guard line.length > 0 else {
                return false
            }
            return (line.attribute(
                NotionLikeTextEditor.tableLineAttribute,
                at: 0,
                effectiveRange: nil
            ) as? Bool) == true
        }
    }
}

// MARK: - Shared Styles
private extension KnowledgeCardView {
    var cardBackground: some View {
        Rectangle()
            .fill(resolvedTheme.cardBackgroundStyle)
            .overlay(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.black.opacity(0.08), Color.white.opacity(0.03)]
                        : [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    var bottomLiquidGlassLayer: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 72)
                .overlay {
                    if #available(iOS 26.0, *) {
                        (colorScheme == .dark ? Color.white.opacity(0.02) : Color.white.opacity(0.03))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.25),
                            .black.opacity(0.8),
                            .black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            LinearGradient(
                colors: colorScheme == .dark ? [.clear, .white.opacity(0.08)] : [.clear, .white.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .allowsHitTesting(false)
    }

    func tagSection(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text("# \(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.zdAccentDeep.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.zdAccentSoft.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Generic Content Block Container
struct ContentBlockView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let trailing: AnyView?
    let borderGradient: LinearGradient?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        trailing: AnyView? = nil,
        borderGradient: LinearGradient? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.borderGradient = borderGradient
        self.content = content
    }

    var body: some View {
        Group {
            if let borderGradient {
                blockContent
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(borderGradient, lineWidth: 0.8)
                            .opacity(0.58)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.07)
                                    : Color.white.opacity(0.16),
                                lineWidth: 0.4
                            )
                            .padding(1)
                    )
            } else {
                blockContent
                    .zdHeavyBorder(cornerRadius: 15, lineWidth: 0.9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.zdAccentDeep.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var blockContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer(minLength: 8)

                if let trailing {
                    trailing.foregroundStyle(Color.zdAccentDeep.opacity(0.86))
                }
            }
            content()
        }
        .padding(14)
        .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - 卡片图片瓦片
struct CardImageTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let source: String
    var stretchToFillWidth = false

    var body: some View {
        let cornerRadius: CGFloat = stretchToFillWidth ? 14 : 12

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.zdSurfaceElevated : Color.white)
            cardImage
        }
        .frame(maxWidth: stretchToFillWidth ? .infinity : nil)
        .frame(width: stretchToFillWidth ? nil : 152, height: stretchToFillWidth ? 188 : 108)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    Color.zdAccentDeep.opacity(0.24),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private var cardImage: some View {
        if let image = localImage(source) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: source), url.scheme != nil {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func localImage(_ source: String) -> UIImage? {
        imageFromLocalPathOrDataURI(source)
    }
}

// MARK: - 毛玻璃芯片
struct LiquidGlassChip: View {
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.white.opacity(0.06)
                    .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - 全屏图片查看器
struct FullscreenImageViewer: View {
    let source: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(scale == 1.0 ? max(0.4, 0.95 - Double(abs(offset.height) / 1000.0)) : 0.95)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            imageContent
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = finalScale * value
                            }
                            .onEnded { value in
                                finalScale *= value
                                if finalScale < 1.0 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        finalScale = 1.0
                                        scale = 1.0
                                        offset = .zero
                                        finalOffset = .zero
                                    }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: finalOffset.width + value.translation.width,
                                        height: finalOffset.height + value.translation.height
                                    )
                                } else {
                                    offset = value.translation
                                }
                            }
                            .onEnded { value in
                                if scale > 1.0 {
                                    finalOffset = offset
                                } else {
                                    if abs(value.translation.height) > 120 || abs(value.translation.width) > 120 {
                                        onDismiss()
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            offset = .zero
                                            finalOffset = .zero
                                        }
                                    }
                                }
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if scale > 1.0 {
                            scale = 1.0
                            finalScale = 1.0
                            offset = .zero
                            finalOffset = .zero
                        } else {
                            scale = 2.5
                            finalScale = 2.5
                        }
                    }
                }
                .onTapGesture(count: 1) {
                    onDismiss()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let image = localImage(source) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else if let url = URL(string: source), url.scheme != nil {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .empty:
                    ProgressView().tint(.white)
                default:
                    VStack(spacing: 8) {
                        Image(systemName: "photo").font(.title2)
                        Text("图片加载失败").font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo").font(.title2)
                Text("无效的图片地址").font(.footnote)
            }
            .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func localImage(_ source: String) -> UIImage? {
        imageFromLocalPathOrDataURI(source)
    }
}

private func imageFromLocalPathOrDataURI(_ source: String) -> UIImage? {
    #if canImport(UIKit)
    var path = source
    if source.hasPrefix("file://") {
        path = String(source.dropFirst("file://".count))
    }
    
    let filename = (path as NSString).lastPathComponent
    if path.contains("ModuleImages/") || filename.hasPrefix("module-image-") {
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let currentPath = docsDir.appendingPathComponent("ModuleImages").appendingPathComponent(filename).path
            if let image = UIImage(contentsOfFile: currentPath) {
                return image
            }
        }
    }

    if path.hasPrefix("/") {
        return UIImage(contentsOfFile: path)
    }
    if let dataURIImage = imageFromDataURI(source) {
        return dataURIImage
    }
    #endif
    return nil
}

private func imageFromDataURI(_ source: String) -> UIImage? {
    #if canImport(UIKit)
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix("data:"),
          let commaIndex = trimmed.firstIndex(of: ",") else {
        return nil
    }

    let metadataStart = trimmed.index(trimmed.startIndex, offsetBy: 5)
    let metadata = String(trimmed[metadataStart..<commaIndex]).lowercased()
    guard metadata.contains("base64"),
          metadata.contains("image/") else {
        return nil
    }

    let payload = String(trimmed[trimmed.index(after: commaIndex)...])
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: "\r", with: "")
        .replacingOccurrences(of: "\t", with: "")
        .replacingOccurrences(of: " ", with: "")
    guard let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) else {
        return nil
    }
    return UIImage(data: data)
    #else
    return nil
    #endif
}

// MARK: - 代码高亮文本
struct HighlightedCodeText: View {
    @Environment(\.colorScheme) private var colorScheme

    let code: String
    let language: CodeDisplayLanguage
    let wrapLines: Bool

    private var highlighted: AttributedString {
        BasicCodeHighlighter.highlight(code: code, language: language)
    }

    var body: some View {
        Group {
            if wrapLines {
                Text(highlighted)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(colorScheme == .dark ? Color.zdSurfaceElevated : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(highlighted)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(12)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .background(colorScheme == .dark ? Color.zdSurfaceElevated : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

// MARK: - 代码高亮内联编辑器（渲染态直接编辑）
struct InlineHighlightedCodeEditor: UIViewRepresentable {
    @Binding var text: String
    let language: CodeDisplayLanguage
    @Binding var isEditing: Bool
    let wrapLines: Bool
    let isHeightCapped: Bool
    var clearBackground: Bool = false
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        // Force TextKit 1 to bypass iOS 16+ horizontal scrolling and clipping bugs (keeps text visible off-screen)
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .zero)
        layoutManager.addTextContainer(textContainer)

        let textView = LayoutAwareTextView(frame: .zero, textContainer: textContainer)
        textView.wrapLines = wrapLines
        textView.delegate = context.coordinator
        textView.clipsToBounds = true
        // Keep layout contiguous so long single-line code can report full width reliably.
        textView.layoutManager.allowsNonContiguousLayout = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = clearBackground ? .clear : .secondarySystemBackground
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.configureWrapBehavior(for: textView, wrapLines: wrapLines)
        context.coordinator.applyHighlight(in: textView, preservingSelection: false)
        textView.isEditable = true
        textView.isSelectable = true
        textView.onLayout = { [weak textView] in
            guard let textView else { return }
            context.coordinator.reportContentHeight(for: textView)
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if let customClass = uiView as? LayoutAwareTextView {
            customClass.wrapLines = wrapLines
        }
        context.coordinator.parent = self
        let wrapChanged = context.coordinator.configureWrapBehavior(for: uiView, wrapLines: wrapLines)
        if wrapChanged {
            context.coordinator.applyHighlight(in: uiView, preservingSelection: false)
            context.coordinator.forceLayoutRefresh(in: uiView)
        }
        context.coordinator.syncTextIfNeeded(in: uiView)
        uiView.isEditable = true
        uiView.isSelectable = true
        uiView.backgroundColor = clearBackground ? .clear : .secondarySystemBackground
        context.coordinator.reportContentHeight(for: uiView)
        DispatchQueue.main.async {
            context.coordinator.reportContentHeight(for: uiView)
        }

        if !isEditing, uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.resignFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth: CGFloat
        if let proposedWidth = proposal.width, proposedWidth > 0 {
            targetWidth = floor(proposedWidth)
        } else if uiView.bounds.width > 0 {
            targetWidth = floor(uiView.bounds.width)
        } else {
            targetWidth = 320
        }
        let targetHeight: CGFloat
        if wrapLines {
            let measured = uiView.sizeThatFits(
                CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
            )
            targetHeight = max(1, ceil(measured.height))
        } else {
            let explicitLineCount = max(1, (uiView.text ?? "").components(separatedBy: "\n").count)
            let font = uiView.font ?? BasicCodeHighlighter.editorBaseFont
            let insets = uiView.textContainerInset.top + uiView.textContainerInset.bottom
            targetHeight = max(1, ceil(CGFloat(explicitLineCount) * font.lineHeight + insets))
        }
        
        let finalHeight = proposal.height.map { min(targetHeight, $0) } ?? targetHeight
        return CGSize(width: targetWidth, height: finalHeight)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InlineHighlightedCodeEditor
        private var isApplyingProgrammaticChange = false
        private var lastReportedHeight: CGFloat = 0
        private var lastHeightCappedState = false
        private var lastWrapLinesState: Bool?

        init(parent: InlineHighlightedCodeEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard !parent.isEditing else { return }
            DispatchQueue.main.async {
                guard !self.parent.isEditing else { return }
                self.parent.isEditing = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard parent.isEditing else { return }
            DispatchQueue.main.async {
                guard self.parent.isEditing else { return }
                self.parent.isEditing = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else {
                return
            }

            let latest = textView.text ?? ""
            if parent.text != latest {
                DispatchQueue.main.async {
                    if self.parent.text != latest {
                        self.parent.text = latest
                    }
                }
            }

            guard textView.markedTextRange == nil else {
                return
            }

            applyHighlight(in: textView, preservingSelection: true)
            reportContentHeight(for: textView)
        }

        @discardableResult
        func configureWrapBehavior(for textView: UITextView, wrapLines: Bool) -> Bool {
            let didWrapModeChange = lastWrapLinesState != wrapLines
            textView.alwaysBounceVertical = parent.isHeightCapped
            textView.showsVerticalScrollIndicator = parent.isHeightCapped

            if wrapLines {
                textView.isScrollEnabled = parent.isHeightCapped
                textView.textContainer.widthTracksTextView = true
                textView.textContainer.lineBreakMode = .byWordWrapping
                textView.textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
                textView.showsHorizontalScrollIndicator = false
                textView.alwaysBounceHorizontal = false
                textView.isDirectionalLockEnabled = false
                textView.setContentOffset(CGPoint(x: 0, y: textView.contentOffset.y), animated: false)
            } else {
                textView.isScrollEnabled = true
                textView.textContainer.size = CGSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
                textView.textContainer.widthTracksTextView = false
                textView.textContainer.lineBreakMode = .byClipping
                textView.showsHorizontalScrollIndicator = true
                textView.alwaysBounceHorizontal = true
                textView.isDirectionalLockEnabled = false
                if didWrapModeChange {
                    textView.setContentOffset(CGPoint(x: 0, y: textView.contentOffset.y), animated: false)
                }
            }
            if let layoutAwareTextView = textView as? LayoutAwareTextView {
                layoutAwareTextView.refreshHorizontalOverflowMetricsIfNeeded()
            }

            if parent.isHeightCapped && !lastHeightCappedState {
                textView.setContentOffset(.zero, animated: false)
            }
            lastHeightCappedState = parent.isHeightCapped
            lastWrapLinesState = wrapLines
            return didWrapModeChange
        }

        func syncTextIfNeeded(in textView: UITextView) {
            let current = textView.text ?? ""
            guard current != parent.text else {
                return
            }
            applyHighlight(in: textView, preservingSelection: false)
            reportContentHeight(for: textView)
        }

        func applyHighlight(in textView: UITextView, preservingSelection: Bool) {
            let selection = textView.selectedRange
            let highlighted = NSMutableAttributedString(attributedString: BasicCodeHighlighter.highlightedNSAttributedString(
                code: parent.text,
                language: parent.language
            ))

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = parent.wrapLines ? .byWordWrapping : .byClipping
            highlighted.addAttribute(
                .paragraphStyle,
                value: paragraph,
                range: NSRange(location: 0, length: highlighted.length)
            )

            isApplyingProgrammaticChange = true
            textView.attributedText = highlighted
            var typingAttributes = BasicCodeHighlighter.editorTypingAttributes
            typingAttributes[.paragraphStyle] = paragraph
            textView.typingAttributes = typingAttributes
            if preservingSelection {
                let bounded = NSRange(
                    location: max(0, min(selection.location, highlighted.length)),
                    length: 0
                )
                textView.selectedRange = bounded
            } else {
                let targetLocation: Int
                if textView.isFirstResponder {
                    // Keep editing behaviour: move caret to the latest text tail.
                    targetLocation = highlighted.length
                } else {
                    // In view mode, always reset to the head to avoid stale selection offsets.
                    targetLocation = 0
                }
                textView.selectedRange = NSRange(location: targetLocation, length: 0)
            }
            isApplyingProgrammaticChange = false
            if let layoutAwareTextView = textView as? LayoutAwareTextView {
                layoutAwareTextView.refreshHorizontalOverflowMetricsIfNeeded()
            }
            if !parent.wrapLines, !textView.isFirstResponder, !preservingSelection {
                textView.setContentOffset(CGPoint(x: 0, y: textView.contentOffset.y), animated: false)
            }
            if parent.wrapLines, !textView.isFirstResponder {
                textView.setContentOffset(CGPoint(x: 0, y: textView.contentOffset.y), animated: false)
            }
        }

        func forceLayoutRefresh(in textView: UITextView) {
            let fullRange = NSRange(location: 0, length: textView.textStorage.length)
            textView.layoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            if let layoutAwareTextView = textView as? LayoutAwareTextView {
                layoutAwareTextView.refreshHorizontalOverflowMetricsIfNeeded()
            }
        }

        func reportContentHeight(for textView: UITextView) {
            guard let onContentHeightChange = parent.onContentHeightChange else {
                return
            }
            let height: CGFloat
            if parent.wrapLines {
                let width = textView.bounds.width
                guard width > 120 else {
                    return
                }
                let fitted = textView.sizeThatFits(
                    CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                )
                height = max(1, ceil(fitted.height))
            } else {
                let explicitLineCount = max(1, (textView.text ?? "").components(separatedBy: "\n").count)
                let font = textView.font ?? BasicCodeHighlighter.editorBaseFont
                let insets = textView.textContainerInset.top + textView.textContainerInset.bottom
                height = max(1, ceil(CGFloat(explicitLineCount) * font.lineHeight + insets))
            }
            guard abs(height - lastReportedHeight) > 0.5 else {
                return
            }
            lastReportedHeight = height
            DispatchQueue.main.async {
                onContentHeightChange(height)
            }
        }
    }
}

private final class LayoutAwareTextView: UITextView, UIGestureRecognizerDelegate {
    var onLayout: (() -> Void)?
    var wrapLines: Bool = true
    private weak var prioritisedAncestorScrollView: UIScrollView?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        panGestureRecognizer.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        panGestureRecognizer.delegate = self
    }

    // When not wrapping lines and there is horizontal content overflow,
    // ensure horizontal pans are recognised by this text view rather than
    // being swallowed by an ancestor SwiftUI ScrollView.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer else {
            return true
        }

        // In wrap mode, text view only handles vertical drags when it can actually scroll.
        if wrapLines {
            let hasVerticalOverflow = contentSize.height > bounds.height + 0.5
            if !hasVerticalOverflow { return false }
            let velocity = panGestureRecognizer.velocity(in: self)
            return abs(velocity.y) >= abs(velocity.x)
        }

        let velocity = panGestureRecognizer.velocity(in: self)
        let hasHorizontalOverflow = contentSize.width > bounds.width + 0.5
        let hasVerticalOverflow = contentSize.height > bounds.height + 0.5
        guard hasHorizontalOverflow || hasVerticalOverflow else { return false }

        // Velocity can be near-zero at pan-begin; don't reject too early.
        if abs(velocity.x) < 1, abs(velocity.y) < 1 {
            return true
        }

        if abs(velocity.x) > abs(velocity.y) {
            return hasHorizontalOverflow
        }
        return hasVerticalOverflow
    }

    // Ask UIKit to let us scroll simultaneously with the outer ScrollView
    // only when the drag direction matches our scrollable axis.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Always allow simultaneous recognition so the outer vertical
        // ScrollView still works when the user scrolls vertically.
        return true
    }

    // When horizontal overflow exists, ask any ancestor scroll-view's
    // pan gesture to wait until ours fails, so we get first shot at
    // horizontal drags.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer == panGestureRecognizer, !wrapLines else {
            return false
        }
        let hasHorizontalOverflow = contentSize.width > bounds.width + 0.5
        guard hasHorizontalOverflow else { return false }

        // If the other gesture is a pan on a different scroll view
        // (e.g. the parent SwiftUI ScrollView), require it to wait.
        if let otherPan = otherGestureRecognizer as? UIPanGestureRecognizer,
           otherPan != panGestureRecognizer,
           otherGestureRecognizer.view is UIScrollView {
            return true
        }
        return false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
        refreshHorizontalOverflowMetricsIfNeeded()
    }

    func refreshHorizontalOverflowMetricsIfNeeded() {
        guard !wrapLines else {
            showsHorizontalScrollIndicator = false
            alwaysBounceHorizontal = false
            return
        }

        let hasHorizontalOverflow = contentSize.width > bounds.width + 0.5
        showsHorizontalScrollIndicator = hasHorizontalOverflow
        alwaysBounceHorizontal = hasHorizontalOverflow
        if hasHorizontalOverflow {
            prioritiseHorizontalPanAgainstAncestorScrollViewIfNeeded()
        } else if contentOffset.x != 0 {
            setContentOffset(CGPoint(x: 0, y: contentOffset.y), animated: false)
        }
    }

    private func prioritiseHorizontalPanAgainstAncestorScrollViewIfNeeded() {
        guard let ancestorScrollView = nearestAncestorScrollView() else { return }
        guard ancestorScrollView !== prioritisedAncestorScrollView else { return }
        ancestorScrollView.panGestureRecognizer.require(toFail: panGestureRecognizer)
        prioritisedAncestorScrollView = ancestorScrollView
    }

    private func nearestAncestorScrollView() -> UIScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? UIScrollView, scrollView !== self {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}

// MARK: - 代码显示语言
enum CodeDisplayLanguage: String, CaseIterable {
    case swift = "Swift"
    case java = "Java"
    case javascript = "JavaScript"
    case c = "C"
    case cpp = "C++"
    case python = "Python"
    case sql = "SQL"
    case plain = "Plain Text"

    static var commonCases: [CodeDisplayLanguage] {
        [.swift, .java, .javascript, .c, .cpp, .python, .sql, .plain]
    }

    var displayName: String { rawValue }

    static func parse(from value: String) -> CodeDisplayLanguage {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "js" { return .javascript }
        if normalized == "py" { return .python }
        return commonCases.first(where: { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }) ?? .plain
    }
}

// MARK: - 基础代码高亮
enum BasicCodeHighlighter {
    static var editorBaseFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    }

    static var editorTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: editorBaseFont,
            .foregroundColor: UIColor.label.withAlphaComponent(0.9)
        ]
    }

    static func highlight(code: String, language: CodeDisplayLanguage) -> AttributedString {
        var attributed = AttributedString(code)
        applyColor(to: &attributed, in: code, pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'", color: .orange.opacity(0.9))
        applyColor(to: &attributed, in: code, pattern: "\\b\\d+(?:\\.\\d+)?\\b", color: .teal)
        applyColor(to: &attributed, in: code, pattern: language.keywordPattern, color: .purple.opacity(0.92))
        applyColor(to: &attributed, in: code, pattern: language.commentPattern, color: .secondary)
        return attributed
    }

    static func highlightedNSAttributedString(
        code: String,
        language: CodeDisplayLanguage
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: code,
            attributes: editorTypingAttributes
        )
        applyColor(
            to: attributed,
            in: code,
            pattern: "\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'",
            color: UIColor.systemOrange
        )
        applyColor(
            to: attributed,
            in: code,
            pattern: "\\b\\d+(?:\\.\\d+)?\\b",
            color: UIColor.systemTeal
        )
        applyColor(
            to: attributed,
            in: code,
            pattern: language.keywordPattern,
            color: UIColor.systemPurple
        )
        applyColor(
            to: attributed,
            in: code,
            pattern: language.commentPattern,
            color: UIColor.secondaryLabel
        )
        return attributed
    }

    private static func applyColor(
        to attributed: inout AttributedString,
        in source: String,
        pattern: String,
        color: Color
    ) {
        guard !pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        regex.enumerateMatches(in: source, options: [], range: nsRange) { match, _, _ in
            guard let range = match?.range,
                  let stringRange = Range(range, in: source),
                  let attributedRange = Range(stringRange, in: attributed) else { return }
            attributed[attributedRange].foregroundColor = color
        }
    }

    private static func applyColor(
        to attributed: NSMutableAttributedString,
        in source: String,
        pattern: String,
        color: UIColor
    ) {
        guard !pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        regex.enumerateMatches(in: source, options: [], range: nsRange) { match, _, _ in
            guard let range = match?.range else { return }
            attributed.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
}

extension CodeDisplayLanguage {
    var keywordPattern: String {
        let keywords: [String]
        switch self {
        case .swift: keywords = ["class", "struct", "enum", "func", "var", "let", "if", "else", "for", "while", "guard", "return", "import", "protocol", "extension", "switch", "case"]
        case .java: keywords = ["class", "public", "private", "protected", "static", "void", "int", "double", "boolean", "if", "else", "for", "while", "return", "new", "import", "package"]
        case .javascript: keywords = ["function", "const", "let", "var", "if", "else", "for", "while", "return", "import", "from", "export", "class", "new", "async", "await"]
        case .c: keywords = ["int", "char", "float", "double", "void", "if", "else", "for", "while", "return", "struct", "typedef", "include", "define"]
        case .cpp: keywords = ["int", "char", "float", "double", "void", "if", "else", "for", "while", "return", "class", "struct", "template", "namespace", "include", "using", "std"]
        case .python: keywords = ["def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "as", "try", "except", "with", "lambda", "None", "True", "False"]
        case .sql: keywords = ["select", "from", "where", "join", "inner", "left", "right", "on", "insert", "into", "update", "delete", "create", "table", "group", "by", "order", "limit", "and", "or"]
        case .plain: keywords = []
        }
        guard !keywords.isEmpty else { return "" }
        return "\\b(?:" + keywords.joined(separator: "|") + ")\\b"
    }

    var commentPattern: String {
        switch self {
        case .python: return "#.*"
        case .sql: return "--.*|/\\*([\\s\\S]*?)\\*/"
        case .plain: return ""
        default: return "//.*|/\\*([\\s\\S]*?)\\*/"
        }
    }
}


// MARK: - Editable Code Snippet Card
struct EditableCodeSnippetCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let snippet: CodeSnippet
    let onChange: (_ name: String, _ language: String, _ code: String) -> Void
    let onDelete: () -> Void

    @State private var isEditingName = false
    @State private var isEditingCode = false
    @State private var isWrapEnabled = false
    @State private var name = ""
    @State private var language = ""
    @State private var code = ""
    @State private var isCopied = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Group {
                    if isEditingName {
                        TextField("代码块名称", text: $name)
                            .font(.subheadline.weight(.semibold))
                            .focused($isNameFocused)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                                    isEditingName = false
                                }
                            }
                    } else {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                                    isEditingName = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                    isNameFocused = true
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 6)

                HStack(spacing: isWrapEnabled ? 4 : 6) {
                    Menu {
                        Button(isWrapEnabled ? "关闭换行展示" : "开启换行展示") {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                                isWrapEnabled.toggle()
                            }
                        }

                        Divider()

                        ForEach(CodeDisplayLanguage.commonCases, id: \.self) { option in
                            Button(option.displayName) {
                                language = option.displayName
                            }
                        }
                    } label: {
                        Text(language)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    if !isWrapEnabled {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                                isWrapEnabled = true
                            }
                        } label: {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)
                    }

                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(Color.zdAccentDeep.opacity(0.88))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.zdSurfaceElevated)

            Divider()

            ZStack {
                InlineHighlightedCodeEditor(
                    text: $code,
                    language: CodeDisplayLanguage.parse(from: language),
                    isEditing: $isEditingCode,
                    wrapLines: isWrapEnabled,
                    isHeightCapped: false
                )
                .frame(minHeight: 128)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.15),
                    radius: 8,
                    x: 0,
                    y: 6
                )

                if !isEditingCode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                                isEditingCode = true
                            }
                        }
                }
            }
            .padding(12)

            HStack {
                Spacer()
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = code
                    #endif
                    withAnimation(.easeInOut(duration: 0.15)) { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.15)) { isCopied = false }
                    }
                } label: {
                    ZStack {
                        Image(systemName: "doc.on.doc")
                            .opacity(isCopied ? 0 : 1)
                        Image(systemName: "checkmark")
                            .opacity(isCopied ? 1 : 0)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCopied ? Color.zdAccentSoft : .secondary)
                    .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .animation(.easeInOut(duration: 0.15), value: isCopied)
            }
            .frame(height: 34)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .zdHeavyBorder(cornerRadius: 10, lineWidth: 1.75)
        .onChange(of: name) { _, _ in onChange(name, language, code) }
        .onChange(of: language) { _, _ in onChange(name, language, code) }
        .onChange(of: code) { _, _ in onChange(name, language, code) }
        .onAppear { syncStateFromSnippet() }
        .onChange(of: snippet) { _, _ in
            if !isEditingName && !isEditingCode { syncStateFromSnippet() }
        }
    }

    private func syncStateFromSnippet() {
        name = snippet.name
        language = snippet.language
        code = snippet.code
        isWrapEnabled = false
    }
}

// MARK: - Detail Screen Container
enum EditorUndoAction {
    case module(RemovedModuleSnapshot)
    case image(RemovedImageSnapshot)
    case codeEntry(RemovedCodeEntrySnapshot)
}
