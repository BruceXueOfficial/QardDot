import Foundation
import Combine

struct RemovedModuleSnapshot {
    let module: CardBlock
    let index: Int
}

struct RemovedImageSnapshot {
    let moduleID: UUID
    let source: String
    let index: Int
}

struct RemovedCodeEntrySnapshot {
    let moduleID: UUID
    let snippet: CodeSnippet
    let index: Int
}

@MainActor
final class KnowledgeCardViewModel: ObservableObject {
    @Published private(set) var card: KnowledgeCard

    init(card: KnowledgeCard) {
        self.card = card
        ensureModulesIfNeeded()
    }

    // MARK: - Shared
    func updateThemeColor(_ color: CardThemeColor) {
        guard card.themeColor != color else {
            return
        }
        card.themeColor = color
        card.touchUpdatedAt()
    }

    func updateTitle(_ title: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty, card.title != normalizedTitle else {
            return
        }
        card.title = normalizedTitle
        card.touchUpdatedAt()
    }

    func replaceTags(_ tags: [String]) {
        let sanitizedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        card.tags = sanitizedTags.isEmpty ? nil : sanitizedTags
        card.touchUpdatedAt()
    }

    func removeTag(at index: Int) {
        var current = card.tags ?? []
        guard current.indices.contains(index) else { return }
        current.remove(at: index)
        card.tags = current.isEmpty ? nil : current
        card.touchUpdatedAt()
    }

    func updateModuleTitle(id: UUID, title: String) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        current[index].moduleTitle = trimmed.isEmpty ? defaultModuleTitle(for: current[index].kind) : trimmed
        setModules(current, touchUpdatedAt: true)
    }

    var modules: [CardBlock] {
        card.modules ?? []
    }

    func ensureModulesIfNeeded() {
        guard card.modules == nil else {
            if let existing = card.modules {
                card.modules = normalizeModules(existing)
            }
            syncLegacyFieldsFromModules(touchUpdatedAt: false)
            return
        }

        let fallback = makeFallbackModules()
        setModules(fallback, touchUpdatedAt: false)
    }

    @discardableResult
    func addModule(_ kind: CardBlockKind, after anchorID: UUID? = nil) -> UUID {
        ensureModulesIfNeeded()

        let newModule = newModuleTemplate(kind)
        var current = modules

        if let anchorID,
           let anchorIndex = current.firstIndex(where: { $0.id == anchorID }) {
            current.insert(newModule, at: anchorIndex + 1)
        } else {
            current.append(newModule)
        }

        setModules(current, touchUpdatedAt: true)
        return newModule.id
    }

    func updateTextModule(id: UUID, text: String) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return
        }
        current[index].text = text
        setModules(current, touchUpdatedAt: true)
    }

    func updateImageModule(id: UUID, moduleTitle: String, source: String) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return
        }

        current[index].moduleTitle = moduleTitle
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            current[index].imageURLs = nil
            current[index].imageURL = nil
        } else {
            current[index].imageURLs = [normalized]
            current[index].imageURL = normalized
        }
        setModules(current, touchUpdatedAt: true)
    }

    func updateImageModule(id: UUID, source: String) {
        guard let existingTitle = card.modules?.first(where: { $0.id == id })?.moduleTitle else {
            updateImageModule(id: id, moduleTitle: defaultModuleTitle(for: .image), source: source)
            return
        }
        updateImageModule(id: id, moduleTitle: existingTitle, source: source)
    }

    @discardableResult
    func appendImageToModule(id: UUID, source: String, maxCount: Int = 5) -> Bool {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return false
        }

        var sources = normalizedImageSources(of: current[index], limit: maxCount)
        guard sources.count < maxCount else {
            return false
        }

        sources.append(normalized)
        current[index].imageURLs = sources
        current[index].imageURL = sources.first
        if current[index].moduleTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            current[index].moduleTitle = defaultModuleTitle(for: .image)
        }
        setModules(current, touchUpdatedAt: true)
        return true
    }

    @discardableResult
    func removeImageFromModule(id: UUID, at imageIndex: Int) -> RemovedImageSnapshot? {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        var sources = normalizedImageSources(of: current[index], limit: 5)
        guard sources.indices.contains(imageIndex) else {
            return nil
        }

        let removedSource = sources[imageIndex]
        sources.remove(at: imageIndex)
        current[index].imageURLs = sources.isEmpty ? nil : sources
        current[index].imageURL = sources.first
        setModules(current, touchUpdatedAt: true)
        return RemovedImageSnapshot(
            moduleID: id,
            source: removedSource,
            index: imageIndex
        )
    }

    @discardableResult
    func restoreImageToModule(_ snapshot: RemovedImageSnapshot) -> Bool {
        guard var current = card.modules,
              let moduleIndex = current.firstIndex(where: { $0.id == snapshot.moduleID }) else {
            return false
        }

        var sources = normalizedImageSources(of: current[moduleIndex], limit: nil)
        guard sources.count < 5 else {
            return false
        }

        let insertIndex = min(max(snapshot.index, 0), sources.count)
        sources.insert(snapshot.source, at: insertIndex)
        current[moduleIndex].imageURLs = sources
        current[moduleIndex].imageURL = sources.first
        setModules(current, touchUpdatedAt: true)
        return true
    }

    func updateCodeModule(id: UUID, name: String, language: String, code: String) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return
        }

        var snippets = normalizedCodeSnippets(of: current[index])
        if snippets.isEmpty {
            snippets = [CodeSnippet(name: "未命名代码块", language: "Swift", code: "")]
        }
        let first = snippets[0]
        snippets[0] = CodeSnippet(id: first.id, name: name, language: language, code: code)
        current[index].codeSnippets = snippets
        current[index].codeSnippet = snippets.first
        setModules(current, touchUpdatedAt: true)
    }

    @discardableResult
    func addCodeEntry(to moduleID: UUID) -> UUID? {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == moduleID }) else {
            return nil
        }

        let entry = CodeSnippet(name: "未命名代码块", language: "Swift", code: "")
        var snippets = normalizedCodeSnippets(of: current[index])
        snippets.append(entry)
        current[index].codeSnippets = snippets
        current[index].codeSnippet = snippets.first
        setModules(current, touchUpdatedAt: true)
        return entry.id
    }

    func updateCodeEntry(moduleID: UUID, snippetID: UUID, name: String, language: String, code: String) {
        guard var current = card.modules,
              let moduleIndex = current.firstIndex(where: { $0.id == moduleID }) else {
            return
        }

        var snippets = normalizedCodeSnippets(of: current[moduleIndex])
        guard let snippetIndex = snippets.firstIndex(where: { $0.id == snippetID }) else {
            return
        }

        snippets[snippetIndex] = CodeSnippet(
            id: snippetID,
            name: name,
            language: language,
            code: code
        )
        current[moduleIndex].codeSnippets = snippets
        current[moduleIndex].codeSnippet = snippets.first
        setModules(current, touchUpdatedAt: true)
    }

    @discardableResult
    func removeCodeEntry(moduleID: UUID, snippetID: UUID) -> RemovedCodeEntrySnapshot? {
        guard var current = card.modules,
              let moduleIndex = current.firstIndex(where: { $0.id == moduleID }) else {
            return nil
        }

        var snippets = normalizedCodeSnippets(of: current[moduleIndex])
        guard let snippetIndex = snippets.firstIndex(where: { $0.id == snippetID }) else {
            return nil
        }

        let removed = snippets.remove(at: snippetIndex)
        current[moduleIndex].codeSnippets = snippets.isEmpty ? nil : snippets
        current[moduleIndex].codeSnippet = snippets.first
        setModules(current, touchUpdatedAt: true)
        return RemovedCodeEntrySnapshot(
            moduleID: moduleID,
            snippet: removed,
            index: snippetIndex
        )
    }

    @discardableResult
    func restoreCodeEntry(_ snapshot: RemovedCodeEntrySnapshot) -> UUID? {
        guard var current = card.modules,
              let moduleIndex = current.firstIndex(where: { $0.id == snapshot.moduleID }) else {
            return nil
        }
        var snippets = normalizedCodeSnippets(of: current[moduleIndex])
        let insertIndex = min(max(snapshot.index, 0), snippets.count)
        snippets.insert(snapshot.snippet, at: insertIndex)
        current[moduleIndex].codeSnippets = snippets
        current[moduleIndex].codeSnippet = snippets.first
        setModules(current, touchUpdatedAt: true)
        return snapshot.snippet.id
    }

    func updateLinkModule(id: UUID, title: String, url: String) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return
        }

        let existingID = current[index].linkItems?.first?.id ?? current[index].linkItem?.id ?? UUID()
        let item = LinkItem(
            id: existingID,
            url: url,
            title: title
        )
        current[index].linkItems = [item]
        current[index].linkItem = item
        setModules(current, touchUpdatedAt: true)
    }

    @discardableResult
    func addLinkEntry(to moduleID: UUID, title: String, url: String) -> UUID? {
        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedURL.isEmpty else {
            return nil
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == moduleID }) else {
            return nil
        }

        let entry = LinkItem(url: normalizedURL, title: normalizedTitle)
        var entries = normalizedLinkEntries(of: current[index])
        entries.append(entry)
        current[index].linkItems = entries
        current[index].linkItem = entries.first
        setModules(current, touchUpdatedAt: true)
        return entry.id
    }

    func updateLinkEntry(moduleID: UUID, entryID: UUID, title: String, url: String) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == moduleID }) else {
            return
        }
        var entries = normalizedLinkEntries(of: current[index])
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }
        entries[entryIndex].title = title
        entries[entryIndex].url = url
        current[index].linkItems = entries
        current[index].linkItem = entries.first
        setModules(current, touchUpdatedAt: true)
    }

    func removeLinkEntry(moduleID: UUID, entryID: UUID) {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == moduleID }) else {
            return
        }
        var entries = normalizedLinkEntries(of: current[index])
        entries.removeAll { $0.id == entryID }
        current[index].linkItems = entries.isEmpty ? nil : entries
        current[index].linkItem = entries.first
        setModules(current, touchUpdatedAt: true)
    }

    // MARK: - Linked Cards

    func addLinkedCards(_ ids: Set<UUID>) {
        var current = card.linkedCardIDs ?? []
        let existingSet = Set(current)
        for id in ids where !existingSet.contains(id) {
            current.append(id)
        }
        card.linkedCardIDs = current.isEmpty ? nil : current
        card.touchUpdatedAt()
    }

    func removeLinkedCard(_ linkedID: UUID) {
        var current = card.linkedCardIDs ?? []
        current.removeAll { $0 == linkedID }
        card.linkedCardIDs = current.isEmpty ? nil : current
        card.touchUpdatedAt()
    }

    @discardableResult
    func removeModule(id: UUID) -> RemovedModuleSnapshot? {
        guard var current = card.modules,
              let index = current.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let removed = current.remove(at: index)
        setModules(current, touchUpdatedAt: true)
        return RemovedModuleSnapshot(module: removed, index: index)
    }

    @discardableResult
    func restoreModule(_ snapshot: RemovedModuleSnapshot) -> UUID {
        var current = modules
        let insertIndex = min(max(snapshot.index, 0), current.count)
        current.insert(snapshot.module, at: insertIndex)
        setModules(current, touchUpdatedAt: true)
        return snapshot.module.id
    }

    // MARK: - Legacy API Compatibility

    func updateShortContent(_ content: String) {
        ensureModulesIfNeeded()

        if let firstText = modules.first(where: { $0.kind == .text }) {
            updateTextModule(id: firstText.id, text: content)
            return
        }

        let id = addModule(.text)
        updateTextModule(id: id, text: content)
    }

    func ensureShortCodeModule() {
        if !modules.contains(where: { $0.kind == .code }) {
            _ = addModule(.code)
        }
    }

    func ensureShortImageModule() {
        if !modules.contains(where: { $0.kind == .image }) {
            _ = addModule(.image)
        }
    }

    func ensureShortLinkModule() {
        if !modules.contains(where: { $0.kind == .link }) {
            _ = addModule(.link)
        }
    }

    func addCodeSnippet() {
        _ = addModule(.code)
    }

    func updateCodeSnippet(id: UUID, name: String, language: String, code: String) {
        guard let targetModule = modules.first(where: { block in
            normalizedCodeSnippets(of: block).contains(where: { $0.id == id })
        }) else {
            return
        }
        updateCodeEntry(
            moduleID: targetModule.id,
            snippetID: id,
            name: name,
            language: language,
            code: code
        )
    }

    func removeCodeSnippet(id: UUID) {
        guard let targetModule = modules.first(where: { block in
            normalizedCodeSnippets(of: block).contains(where: { $0.id == id })
        }) else {
            return
        }
        _ = removeCodeEntry(moduleID: targetModule.id, snippetID: id)
    }

    @discardableResult
    func addLink(title: String, url: String) -> Bool {
        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedURL.isEmpty {
            return false
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let moduleID = addModule(.link)
        updateLinkModule(
            id: moduleID,
            title: normalizedTitle.isEmpty ? "未命名链接" : normalizedTitle,
            url: normalizedURL
        )
        return true
    }

    func removeLink(id: UUID) {
        guard let targetModule = modules.first(where: { block in
            if block.linkItem?.id == id { return true }
            return (block.linkItems ?? []).contains(where: { $0.id == id })
        }) else {
            return
        }
        _ = removeModule(id: targetModule.id)
    }

    func addImage(_ pathOrURL: String) {
        let normalized = pathOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let id = addModule(.image)
        updateImageModule(id: id, moduleTitle: defaultModuleTitle(for: .image), source: normalized)
    }

    func removeImage(at index: Int) {
        let imageModules = modules.filter { $0.kind == .image }
        guard imageModules.indices.contains(index) else { return }
        _ = removeModule(id: imageModules[index].id)
    }

}

private extension KnowledgeCardViewModel {
    func setModules(_ nextModules: [CardBlock], touchUpdatedAt: Bool) {
        let normalized = normalizeModules(nextModules)
        card.modules = normalized
        card.blocks = normalized
        syncLegacyFieldsFromModules(touchUpdatedAt: false)
        if touchUpdatedAt {
            card.touchUpdatedAt()
        }
    }

    func syncLegacyFieldsFromModules(touchUpdatedAt: Bool) {
        let current = card.modules ?? []
        card.blocks = current

        let firstText = current.first(where: { $0.kind == .text })?.text ?? ""
        card.content = firstText

        let images = current
            .filter { $0.kind == .image }
            .flatMap { normalizedImageSources(of: $0, limit: 5) }
        card.images = images.isEmpty ? nil : images

        let snippets = current
            .filter { $0.kind == .code }
            .flatMap { normalizedCodeSnippets(of: $0) }
            .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        card.codeSnippets = snippets.isEmpty ? nil : snippets

        let links = current
            .filter { $0.kind == .link }
            .flatMap { normalizedLinkEntries(of: $0) }
            .filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        card.links = links.isEmpty ? nil : links

        card.type = .short
        if touchUpdatedAt {
            card.touchUpdatedAt()
        }
    }

    func newModuleTemplate(_ kind: CardBlockKind) -> CardBlock {
        switch kind {
        case .text:
            return CardBlock(kind: .text, moduleTitle: defaultModuleTitle(for: .text), text: "")
        case .image:
            return CardBlock(kind: .image, moduleTitle: defaultModuleTitle(for: .image), imageURLs: [])
        case .code:
            return CardBlock(
                kind: .code,
                moduleTitle: defaultModuleTitle(for: .code),
                codeSnippets: [
                    CodeSnippet(
                        name: "未命名代码块",
                        language: "Swift",
                        code: ""
                    )
                ]
            )
        case .link:
            return CardBlock(kind: .link, moduleTitle: defaultModuleTitle(for: .link))
        case .formula:
            return CardBlock(kind: .formula, moduleTitle: defaultModuleTitle(for: .formula), text: "")
        case .linkedCard:
            return CardBlock(kind: .linkedCard, moduleTitle: defaultModuleTitle(for: .linkedCard))
        }
    }

    func makeFallbackModules() -> [CardBlock] {
        if let legacyBlocks = card.modules ?? card.blocks,
           !legacyBlocks.isEmpty {
            return legacyBlocks
        }

        var fallback: [CardBlock] = []
        let normalizedContent = card.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedContent.isEmpty {
            fallback.append(.text(card.content))
        }

        card.images?.forEach {
            fallback.append(.image($0, moduleTitle: defaultModuleTitle(for: .image)))
        }
        if let snippets = card.codeSnippets, !snippets.isEmpty {
            fallback.append(
                CardBlock(
                    kind: .code,
                    moduleTitle: defaultModuleTitle(for: .code),
                    codeSnippets: snippets
                )
            )
        }
        card.links?.forEach {
            fallback.append(
                CardBlock(
                    kind: .link,
                    moduleTitle: defaultModuleTitle(for: .link),
                    linkItems: [$0]
                )
            )
        }

        if fallback.isEmpty {
            fallback = [CardBlock(kind: .text, moduleTitle: defaultModuleTitle(for: .text), text: "")]
        }
        return fallback
    }

    func normalizeModules(_ source: [CardBlock]) -> [CardBlock] {
        source.map { block in
            var copy = block
            let normalizedLegacyTitle = normalizeLegacyModuleTitle(copy.moduleTitle, for: copy.kind)
            copy.moduleTitle = normalizedLegacyTitle
            if copy.moduleTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                copy.moduleTitle = defaultModuleTitle(for: copy.kind)
            }

            if copy.kind == .image {
                let normalizedSources = normalizedImageSources(of: copy, limit: 5)
                copy.imageURLs = normalizedSources.isEmpty ? nil : normalizedSources
                copy.imageURL = normalizedSources.first
            } else {
                copy.imageURLs = nil
                copy.imageURL = nil
            }

            if copy.kind == .code {
                let normalizedSnippets = normalizedCodeSnippets(of: copy)
                copy.codeSnippets = normalizedSnippets.isEmpty ? nil : normalizedSnippets
                copy.codeSnippet = normalizedSnippets.first
            } else {
                copy.codeSnippets = nil
                copy.codeSnippet = nil
            }

            let entries = normalizedLinkEntries(of: copy)
            if !entries.isEmpty {
                copy.linkItems = entries
                copy.linkItem = entries.first
            } else {
                copy.linkItems = nil
                copy.linkItem = nil
            }
            return copy
        }
    }

    func normalizedLinkEntries(of block: CardBlock) -> [LinkItem] {
        let entries: [LinkItem]
        if let items = block.linkItems, !items.isEmpty {
            entries = items
        } else if let item = block.linkItem {
            entries = [item]
        } else {
            entries = []
        }

        return entries.filter {
            !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func normalizedCodeSnippets(of block: CardBlock) -> [CodeSnippet] {
        if let snippets = block.codeSnippets, !snippets.isEmpty {
            return snippets
        }
        if let snippet = block.codeSnippet {
            return [snippet]
        }
        return []
    }

    func normalizedImageSources(of block: CardBlock, limit: Int? = nil) -> [String] {
        let fromArray = (block.imageURLs ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let merged: [String]
        if !fromArray.isEmpty {
            merged = fromArray
        } else if let single = block.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !single.isEmpty {
            merged = [single]
        } else {
            merged = []
        }
        if let limit {
            return Array(merged.prefix(max(limit, 0)))
        }
        return merged
    }

    func defaultModuleTitle(for kind: CardBlockKind) -> String {
        switch kind {
        case .text: return "文本"
        case .image: return "图片"
        case .code: return "代码"
        case .link: return "链接"
        case .formula: return "公式"
        case .linkedCard: return "关联卡片"
        }
    }

    func normalizeLegacyModuleTitle(_ title: String?, for kind: CardBlockKind) -> String? {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return title }
        switch kind {
        case .text:
            if trimmed == "文字" {
                return defaultModuleTitle(for: kind)
            }
        case .image:
            if trimmed == "图片模块" {
                return defaultModuleTitle(for: kind)
            }
        case .code:
            if trimmed == "代码模块" {
                return defaultModuleTitle(for: kind)
            }
        case .link:
            if trimmed == "链接模块" {
                return defaultModuleTitle(for: kind)
            }
        case .formula:
            if trimmed == "公式模块" {
                return defaultModuleTitle(for: kind)
            }
        case .linkedCard:
            break
        }
        return title
    }
}
