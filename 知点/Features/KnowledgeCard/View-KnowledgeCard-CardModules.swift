import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SafariServices)
import SafariServices
#endif

// MARK: - Module List & Editors
extension KnowledgeCardView {
    var moduleCardLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.modules.enumerated()), id: \.element.id) { _, module in
                UnifiedModuleContainer(
                    title: moduleTitle(module),
                    isSelected: selectedModuleID == module.id,
                    headerAccessory: moduleHeaderAccessory(for: module),
                    onTap: {
                        selectedModuleID = module.id
                        dismissKeyboard()
                    },
                    onRename: { newTitle in
                        viewModel.updateModuleTitle(id: module.id, title: newTitle)
                    },
                    onDelete: {
                        if imageSourceMenuModuleID == module.id {
                            imageSourceMenuModuleID = nil
                        }
                        if removingImageTarget?.moduleID == module.id {
                            removingImageTarget = nil
                        }
                        if removingCodeSnippetTarget?.moduleID == module.id {
                            removingCodeSnippetTarget = nil
                        }
                        for snippet in codeSnippets(of: module) {
                            codeEditingStates[snippet.id] = nil
                            codeWrapStates[snippet.id] = nil
                            codeEditorHeights[snippet.id] = nil
                            copiedCodeSnippetIDs.remove(snippet.id)
                        }
                        onDeleteModule?(module.id)
                    }
                ) {
                    moduleBody(module)
                }
                .transition(.moduleInsertRemove)
                .padding(.bottom, 14)
            }

            Color.clear
                .frame(height: 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedModuleID = nil
                    dismissKeyboard()
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: viewModel.modules.map(\.id))
    }

    private func moduleTitle(_ module: CardBlock) -> String {
        let raw = module.moduleTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !raw.isEmpty { return raw }

        switch module.kind {
        case .text: return "总结"
        case .image: return "图片"
        case .code: return "代码"
        case .link: return "链接"
        }
    }

    private func moduleHeaderAccessory(for module: CardBlock) -> AnyView? {
        switch module.kind {
        case .link:
            return AnyView(
                Button {
                    dismissKeyboard()
                    presentLinkComposer(for: module.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.zdAccentDeep.opacity(0.9))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            )
        case .image:
            let isImageLimitReached = imageSources(of: module).count >= 5
            return AnyView(
                Button {
                    guard !isImageLimitReached else { return }
                    dismissKeyboard()
                    imageSourceMenuModuleID = module.id
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.zdAccentDeep.opacity(0.9))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .opacity(isImageLimitReached ? 0.42 : 1)
                .disabled(isImageLimitReached)
                .popover(
                    isPresented: imageSourceMenuBinding(for: module.id),
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) {
                    ImageSourcePickerPopover {
                        chooseImageSource(for: module.id, source: .camera)
                    } onPhotoLibrary: {
                        chooseImageSource(for: module.id, source: .photoLibrary)
                    } onFile: {
                        chooseImageSource(for: module.id, source: .file)
                    }
                    .presentationCompactAdaptation(.popover)
                }
            )
        case .code:
            return AnyView(
                Button {
                    _ = viewModel.addCodeEntry(to: module.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.zdAccentDeep.opacity(0.9))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            )
        default:
            return nil
        }
    }

    @ViewBuilder
    private func moduleBody(_ module: CardBlock) -> some View {
        switch module.kind {
        case .text:
            textModuleBody(module)
        case .image:
            imageModuleBody(module)
        case .code:
            codeModuleBody(module)
        case .link:
            linkModuleBody(module)
        }
    }

    @ViewBuilder
    private func textModuleBody(_ module: CardBlock) -> some View {
        ZStack(alignment: .topLeading) {
            NotionLikeTextEditor(
                text: Binding(
                    get: { module.text ?? "" },
                    set: { value in
                        viewModel.updateTextModule(id: module.id, text: value)
                    }
                ),
                isEditable: true,
                minimumHeight: 156
            )
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)

            if (module.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("点击输入文字内容")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func imageModuleBody(_ module: CardBlock) -> some View {
        let sources = imageSources(of: module)

        VStack(alignment: .leading, spacing: 12) {
            if sources.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .overlay {
                        Text("点击加号添加图片")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                        presentImageSourcePicker(for: module.id)
                    }
            } else if sources.count == 1, let source = sources.first {
                imageTileItem(
                    moduleID: module.id,
                    source: source,
                    index: 0,
                    tileWidth: nil
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let tileWidth: CGFloat = 262
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                            imageTileItem(
                                moduleID: module.id,
                                source: source,
                                index: index,
                                tileWidth: tileWidth
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func imageTileItem(moduleID: UUID, source: String, index: Int, tileWidth: CGFloat?) -> some View {
        let target = ModuleImageTarget(moduleID: moduleID, imageIndex: index)
        let isRemoving = removingImageTarget == target
        let cornerRadius: CGFloat = 14

        CardImageTile(
            source: source,
            stretchToFillWidth: true
        )
        .frame(maxWidth: tileWidth == nil ? .infinity : nil)
        .frame(width: tileWidth)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                removeImageFromModule(target)
            } label: {
                Label("删除图片", systemImage: "trash")
            }
        }
        .onTapGesture {
            dismissKeyboard()
            previewImageSource = source
        }
        .offset(x: isRemoving ? -70 : 0)
        .opacity(isRemoving ? 0 : 1)
        .animation(.easeInOut(duration: 0.23), value: isRemoving)
        .allowsHitTesting(!isRemoving)
    }

    @ViewBuilder
    private func codeModuleBody(_ module: CardBlock) -> some View {
        let snippets = codeSnippets(of: module)

        VStack(alignment: .leading, spacing: 10) {
            if snippets.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .overlay {
                        Text("点击加号添加代码框")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
            } else {
                ForEach(snippets) { snippet in
                    codeSnippetFrame(moduleID: module.id, snippet: snippet)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.27, dampingFraction: 0.84), value: snippets.map(\.id))
    }

    @ViewBuilder
    private func codeSnippetFrame(moduleID: UUID, snippet: CodeSnippet) -> some View {
        let minEditorHeight: CGFloat = 30
        let maxEditorHeight: CGFloat = 200
        let editorVerticalInsets: CGFloat = 24
        let lineHeight = BasicCodeHighlighter.editorBaseFont.lineHeight
        let reserveLinesHeight = lineHeight * 2

        let target = ModuleCodeSnippetTarget(moduleID: moduleID, snippetID: snippet.id)
        let isRemoving = removingCodeSnippetTarget == target
        let isCopied = copiedCodeSnippetIDs.contains(snippet.id)
        let wrapBinding = codeWrapBinding(for: snippet.id)
        let trimmedCode = snippet.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let logicalLines = snippet.code.components(separatedBy: "\n")
        let visualLineCount: Int = {
            if wrapBinding.wrappedValue {
                let approxCharsPerLine = 34.0
                let estimated = logicalLines.reduce(0) { partial, line in
                    let lineLength = max(1, Double(line.count))
                    return partial + max(1, Int(ceil(lineLength / approxCharsPerLine)))
                }
                return max(1, estimated)
            }
            return max(1, logicalLines.count)
        }()
        let estimatedContentHeight = CGFloat(visualLineCount) * lineHeight + editorVerticalInsets + reserveLinesHeight
        let editorHeight: CGFloat = trimmedCode.isEmpty
            ? minEditorHeight
            : min(maxEditorHeight, max(minEditorHeight, ceil(estimatedContentHeight)))
        let isHeightCapped = editorHeight >= (maxEditorHeight - 0.5)

        let languageBinding = Binding(
            get: { snippet.language },
            set: { value in
                viewModel.updateCodeEntry(
                    moduleID: moduleID,
                    snippetID: snippet.id,
                    name: snippet.name,
                    language: value,
                    code: snippet.code
                )
            }
        )

        let codeBinding = Binding(
            get: { snippet.code },
            set: { value in
                viewModel.updateCodeEntry(
                    moduleID: moduleID,
                    snippetID: snippet.id,
                    name: snippet.name,
                    language: snippet.language,
                    code: value
                )
            }
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Menu {
                    ForEach(CodeDisplayLanguage.commonCases, id: \.self) { option in
                        Button(option.displayName) {
                            languageBinding.wrappedValue = option.displayName
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(languageBinding.wrappedValue)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.zdAccentDeep.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.34))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1, height: 14)

                Button {
                    dismissKeyboard()
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        wrapBinding.wrappedValue.toggle()
                    }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.alignleft")
                                .font(.caption2.weight(.semibold))
                            Text("自动换行")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                        }
                        Image(systemName: "text.alignleft")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(wrapBinding.wrappedValue ? Color.zdAccentDeep.opacity(0.96) : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    dismissKeyboard()
                    removeCodeEntryFromModule(target)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.82))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .zIndex(2)

            ZStack(alignment: .topLeading) {
                InlineHighlightedCodeEditor(
                    text: codeBinding,
                    language: CodeDisplayLanguage.parse(from: languageBinding.wrappedValue),
                    isEditing: codeEditingBinding(for: snippet.id),
                    wrapLines: wrapBinding.wrappedValue,
                    isHeightCapped: isHeightCapped,
                    clearBackground: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: editorHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if codeBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("输入代码内容")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .zIndex(1)

            HStack {
                Spacer(minLength: 0)
                Button {
                    copyCodeSnippet(snippetID: snippet.id, code: snippet.code)
                } label: {
                    ZStack {
                        Image(systemName: "doc.on.doc")
                            .opacity(isCopied ? 0 : 1)
                        Image(systemName: "checkmark")
                            .opacity(isCopied ? 1 : 0)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCopied ? Color.zdAccentDeep.opacity(0.92) : .secondary)
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: isCopied)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.1 : 0.08), lineWidth: 0.8)
        )
        .offset(x: isRemoving ? -56 : 0)
        .opacity(isRemoving ? 0 : 1)
        .animation(.easeInOut(duration: 0.22), value: isRemoving)
        .allowsHitTesting(!isRemoving)
    }

    @ViewBuilder
    private func linkModuleBody(_ module: CardBlock) -> some View {
        let entries = visibleLinkEntries(of: module)

        VStack(alignment: .leading, spacing: 10) {
            if entries.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .overlay {
                        Text("点击右上角加号添加链接")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
            } else {
                ForEach(entries) { entry in
                    let resolvedURL = normalizedURL(from: entry.url)

                    Button {
                        selectedModuleID = module.id
                        dismissKeyboard()
                        openLinkEntry(entry, resolvedURL: resolvedURL)
                    } label: {
                        HStack(spacing: 10) {
                            LinkIconCircle(url: resolvedURL)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(linkDisplayTitle(for: entry, resolvedURL: resolvedURL))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(linkSubtitle(for: entry, resolvedURL: resolvedURL))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: resolvedURL == nil ? "exclamationmark.triangle" : "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    resolvedURL == nil
                                        ? Color.orange.opacity(0.8)
                                        : Color.zdAccentDeep.opacity(0.92)
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.08)
                                        : Color.black.opacity(0.05)
                                )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    Color.zdAccentDeep.opacity(colorScheme == .dark ? 0.44 : 0.24),
                                    lineWidth: 0.8
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(.contextMenuPreview, Capsule())
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeLinkEntry(moduleID: module.id, entryID: entry.id)
                        } label: {
                            Label("删除链接", systemImage: "trash")
                        }
                    }
                    .opacity(resolvedURL == nil ? 0.72 : 1)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .animation(.spring(response: 0.25, dampingFraction: 0.86), value: entries.map(\.id))
    }

    private func visibleLinkEntries(of module: CardBlock) -> [LinkItem] {
        let entries = module.linkItems?.isEmpty == false
            ? (module.linkItems ?? [])
            : (module.linkItem.map { [$0] } ?? [])

        return entries.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func openLinkEntry(_ entry: LinkItem, resolvedURL: URL?) {
        guard let resolvedURL else { return }
        activeLinkBrowserDestination = LinkBrowserDestination(
            title: linkDisplayTitle(for: entry, resolvedURL: resolvedURL),
            url: resolvedURL
        )
    }

    private func linkDisplayTitle(for entry: LinkItem, resolvedURL: URL?) -> String {
        let trimmedTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        if let host = resolvedURL?.host, !host.isEmpty {
            return host
        }
        let trimmedURL = entry.url.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedURL.isEmpty ? "未命名链接" : trimmedURL
    }

    private func linkSubtitle(for entry: LinkItem, resolvedURL: URL?) -> String {
        if let host = resolvedURL?.host, !host.isEmpty {
            return host
        }
        let trimmedURL = entry.url.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedURL.isEmpty ? "无效链接" : trimmedURL
    }

    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidates: [String]
        if trimmed.contains("://") {
            candidates = [trimmed]
        } else {
            candidates = ["https://\(trimmed)", trimmed]
        }

        for candidate in candidates {
            guard let url = URL(string: candidate),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let host = url.host,
                  !host.isEmpty else {
                continue
            }
            return url
        }
        return nil
    }

    private func presentLinkComposer(for moduleID: UUID) {
        linkInputTargetModuleID = moduleID
        linkInputTitleDraft = ""
        linkInputURLDraft = ""
        linkInputErrorMessage = nil
    }

    func resetLinkComposerDrafts() {
        linkInputTargetModuleID = nil
        linkInputTitleDraft = ""
        linkInputURLDraft = ""
        linkInputErrorMessage = nil
    }

    func commitPendingLinkEntry() {
        guard let moduleID = linkInputTargetModuleID else { return }
        guard let resolvedURL = normalizedURL(from: linkInputURLDraft) else {
            linkInputErrorMessage = "请输入有效的链接地址"
            return
        }

        let title = linkInputTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = resolvedURL.host ?? resolvedURL.absoluteString
        let finalTitle = title.isEmpty ? fallbackTitle : title
        let added = viewModel.addLinkEntry(
            to: moduleID,
            title: finalTitle,
            url: resolvedURL.absoluteString
        )

        guard added != nil else {
            linkInputErrorMessage = "添加失败，请重试"
            return
        }
        resetLinkComposerDrafts()
    }

    private func codeEditingBinding(for codeSnippetID: UUID) -> Binding<Bool> {
        Binding(
            get: { codeEditingStates[codeSnippetID] ?? false },
            set: { codeEditingStates[codeSnippetID] = $0 }
        )
    }

    private func codeWrapBinding(for codeSnippetID: UUID) -> Binding<Bool> {
        Binding(
            get: { codeWrapStates[codeSnippetID] ?? false },
            set: { codeWrapStates[codeSnippetID] = $0 }
        )
    }

    private func imageSourceMenuBinding(for moduleID: UUID) -> Binding<Bool> {
        Binding(
            get: { imageSourceMenuModuleID == moduleID },
            set: { isPresented in
                if isPresented {
                    imageSourceMenuModuleID = moduleID
                } else if imageSourceMenuModuleID == moduleID {
                    imageSourceMenuModuleID = nil
                }
            }
        )
    }

    func presentImageSourcePicker(for moduleID: UUID) {
        imageSourceMenuModuleID = moduleID
    }

    private func chooseImageSource(for moduleID: UUID, source: ModuleImageSourceOption) {
        imagePickerTargetModuleID = moduleID
        imageSourceMenuModuleID = nil
        switch source {
        case .camera:
            systemImagePickerSource = .camera
            isShowingSystemImagePicker = true
        case .photoLibrary:
            systemImagePickerSource = .photoLibrary
            isShowingSystemImagePicker = true
        case .file:
            isShowingFileImporter = true
        }
    }

    func handlePickedImage(_ image: UIImage?) {
        defer {
            systemImagePickerSource = nil
            imagePickerTargetModuleID = nil
        }
        guard let image,
              let targetID = imagePickerTargetModuleID,
              let data = image.jpegData(compressionQuality: 0.86),
              let persisted = persistImageData(data, preferredExtension: "jpg") else {
            return
        }
        _ = viewModel.appendImageToModule(id: targetID, source: persisted, maxCount: 5)
    }

    func handlePickedImageFile(_ result: Result<URL, Error>) {
        defer {
            imagePickerTargetModuleID = nil
        }

        guard let targetID = imagePickerTargetModuleID else { return }

        switch result {
        case .success(let url):
            guard let persisted = persistImageFile(from: url) else { return }
            _ = viewModel.appendImageToModule(id: targetID, source: persisted, maxCount: 5)
        case .failure:
            break
        }
    }

    private func imageSources(of module: CardBlock) -> [String] {
        let fromArray = (module.imageURLs ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !fromArray.isEmpty {
            return Array(fromArray.prefix(5))
        }
        let single = (module.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return single.isEmpty ? [] : [single]
    }

    private func codeSnippets(of module: CardBlock) -> [CodeSnippet] {
        if let snippets = module.codeSnippets, !snippets.isEmpty {
            return snippets
        }
        if let snippet = module.codeSnippet {
            return [snippet]
        }
        return []
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }

    private func copyCodeSnippet(snippetID: UUID, code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
        withAnimation(.easeInOut(duration: 0.15)) {
            _ = copiedCodeSnippetIDs.insert(snippetID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                _ = copiedCodeSnippetIDs.remove(snippetID)
                    }
                }
            }

    private func removeImageFromModule(_ target: ModuleImageTarget) {
        guard removingImageTarget == nil else { return }
        withAnimation(.easeInOut(duration: 0.23)) {
            removingImageTarget = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
            if let snapshot = viewModel.removeImageFromModule(id: target.moduleID, at: target.imageIndex) {
                onRegisterUndoAction?(.image(snapshot))
            }
            if removingImageTarget == target {
                removingImageTarget = nil
            }
        }
    }

    private func removeCodeEntryFromModule(_ target: ModuleCodeSnippetTarget) {
        guard removingCodeSnippetTarget == nil else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            removingCodeSnippetTarget = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if let snapshot = viewModel.removeCodeEntry(moduleID: target.moduleID, snippetID: target.snippetID) {
                onRegisterUndoAction?(.codeEntry(snapshot))
            }
            codeEditingStates[target.snippetID] = nil
            codeWrapStates[target.snippetID] = nil
            codeEditorHeights[target.snippetID] = nil
            copiedCodeSnippetIDs.remove(target.snippetID)
            if removingCodeSnippetTarget == target {
                removingCodeSnippetTarget = nil
            }
        }
    }

    private func persistImageFile(from sourceURL: URL) -> String? {
        let needsScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: sourceURL) else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        return persistImageData(data, preferredExtension: ext)
    }

    private func persistImageData(_ data: Data, preferredExtension: String) -> String? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ModuleImages", isDirectory: true) else {
            return nil
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let ext = preferredExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeExt = ext.isEmpty ? "jpg" : ext.lowercased()
        let url = dir.appendingPathComponent("module-image-\(UUID().uuidString).\(safeExt)")
        do {
            try data.write(to: url, options: .atomic)
            return url.absoluteString
        } catch {
            return nil
        }
    }
}

struct ModuleImageTarget: Equatable {
    let moduleID: UUID
    let imageIndex: Int
}

struct ModuleCodeSnippetTarget: Equatable {
    let moduleID: UUID
    let snippetID: UUID
}

private enum ModuleImageSourceOption {
    case camera
    case photoLibrary
    case file
}

struct LinkBrowserDestination: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

private struct LinkIconCircle: View {
    let url: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.72))

            if let faviconURL = faviconURL {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    default:
                        Image(systemName: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.zdAccentDeep.opacity(0.9))
                    }
                }
            } else {
                Image(systemName: "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.zdAccentDeep.opacity(0.9))
            }
        }
        .frame(width: 30, height: 30)
        .overlay(
            Circle()
                .stroke(Color.zdAccentDeep.opacity(0.25), lineWidth: 0.75)
        )
    }

    private var faviconURL: URL? {
        guard let host = url?.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "sz", value: "128"),
            URLQueryItem(name: "domain", value: host)
        ]
        return components?.url
    }
}

struct LinkEntryComposerSheet: View {
    @Binding var title: String
    @Binding var url: String
    let errorMessage: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @FocusState private var focusedField: FocusField?

    private enum FocusField {
        case title
        case url
    }

    var body: some View {
        let sectionSpacing: CGFloat = 16
        let fieldHeight: CGFloat = 48

        NavigationStack {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // 链接名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("链接名称")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    TextField(
                        "",
                        text: $title,
                        prompt: Text("链接名称（可选）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
                        .font(.body)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: fieldHeight)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.8)
                        )
                        .focused($focusedField, equals: .title)
                }

                // 链接内容
                VStack(alignment: .leading, spacing: 8) {
                    Text("链接内容")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    TextField(
                        "",
                        text: $url,
                        prompt: Text("点击输入链接内容")
                            .font(.subheadline)
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: fieldHeight)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.8)
                        )
                        .focused($focusedField, equals: .url)
                        .submitLabel(.done)
                        .onSubmit(onConfirm)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.red.opacity(0.86))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("新增链接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加", action: onConfirm)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    focusedField = .url
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

struct LinkInAppBrowserSheet: View {
    let destination: LinkBrowserDestination

    var body: some View {
        #if canImport(SafariServices)
        InAppSafariWebView(url: destination.url)
            .ignoresSafeArea()
        #else
        VStack(spacing: 12) {
            Text(destination.title)
                .font(.headline.weight(.semibold))
            Text(destination.url.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        #endif
    }
}

#if canImport(SafariServices)
private struct InAppSafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
#endif

private struct ImageSourcePickerPopover: View {
    let onCamera: () -> Void
    let onPhotoLibrary: () -> Void
    let onFile: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("选择图片来源")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            imageSourceButton(title: "拍照", action: onCamera)
            imageSourceButton(title: "相册", action: onPhotoLibrary)
            imageSourceButton(title: "文件", action: onFile)
        }
        .padding(16)
        .frame(width: 232)
    }

    @ViewBuilder
    private func imageSourceButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.zdAccentDeep.opacity(0.95))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .zdGlassSurface(cornerRadius: 20, lineWidth: 1.05, isClear: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.zdAccentDeep.opacity(0.42),
                                    Color.zdAccentSoft.opacity(0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private extension AnyTransition {
    static var moduleInsertRemove: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.94)
                .combined(with: .opacity)
                .combined(with: .offset(y: 14)),
            removal: .scale(scale: 0.9, anchor: .top)
                .combined(with: .opacity)
                .combined(with: .offset(y: -16))
        )
    }
}

private struct UnifiedModuleContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isSelected: Bool
    let headerAccessory: AnyView?
    let onTap: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        containerBody
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(containerBackground)
        .clipShape(containerShape)
        .overlay(primaryBorder)
        .overlay(secondaryBorder)
        .shadow(
            color: dragShadowColor,
            radius: 4,
            x: 0,
            y: 2
        )
        .onAppear {
            titleDraft = title
        }
        .onChange(of: title) { _, newValue in
            if !isEditingTitle {
                titleDraft = newValue
            }
        }
        .onChange(of: isTitleFieldFocused) { _, focused in
            if !focused, isEditingTitle {
                commitTitleEdit()
            }
        }
    }

    private var containerBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { onTap() })
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Group {
                if isEditingTitle {
                    TextField("模块名称", text: $titleDraft)
                        .font(.caption.weight(.regular))
                        .foregroundStyle(.secondary)
                        .textFieldStyle(.plain)
                        .focused($isTitleFieldFocused)
                        .onSubmit(commitTitleEdit)
                } else {
                    Text(title)
                        .font(.caption.weight(.regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .onTapGesture {
                            onTap()
                            beginTitleEdit()
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let headerAccessory {
                headerAccessory
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.88))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    private var containerBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.3)
    }

    private var primaryBorder: some View {
        containerShape.stroke(
            LinearGradient(
                colors: [
                    Color.zdAccentDeep.opacity(isSelected ? 0.86 : 0.42),
                    Color.zdAccentSoft.opacity(isSelected ? 0.76 : 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: isSelected ? 1.45 : 0.82
        )
    }

    private var secondaryBorder: some View {
        containerShape
            .stroke(
                colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.18),
                lineWidth: 0.4
            )
            .padding(1)
    }

    private var dragShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.14 : 0.06)
    }

    private func beginTitleEdit() {
        titleDraft = title
        isEditingTitle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isTitleFieldFocused = true
        }
    }

    private func commitTitleEdit() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onRename(trimmed)
        }
        isTitleFieldFocused = false
        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            isEditingTitle = false
        }
    }
}

#if canImport(UIKit)
struct SystemImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary

        var uiType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .photoLibrary: return .photoLibrary
            }
        }
    }

    let sourceType: SourceType
    let onPicked: (UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        if sourceType == .camera,
           UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }

        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (UIImage?) -> Void
        let dismiss: DismissAction

        init(onPicked: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onPicked = onPicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
            onPicked(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            dismiss()
            onPicked(image)
        }
    }
}
#endif

#Preview("KnowledgeCard Detail Screen - Modules") {
    let previewCard = KnowledgeCard.previewShort
    KnowledgeCardDetailDrawerPreviewHost(card: previewCard)
}
