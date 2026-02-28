import Foundation
import Combine

@MainActor
final class KnowledgeCardLibraryStore: ObservableObject {
    @Published private(set) var cards: [KnowledgeCard]
    @Published private(set) var viewCounts: [UUID: Int]
    @Published private(set) var lastViewedAt: [UUID: Date]

    private static let cardsFileName = "knowledge_cards.json"
    private static let viewCountsFileName = "view_counts.json"
    private static let bundledSeedVersionKey = "knowledge_card_bundled_seed_version"
    private static let bundledSeedVersion = "2026-02-formula-structured-v5"

    static func bundledSeedCardsForPreview() -> [KnowledgeCard] {
        KnowledgeCardLibrarySeed.makeCards()
    }

    init(cards: [KnowledgeCard]? = nil) {
        if let cards {
            // 预览 / 测试用途
            self.cards = cards
            self.viewCounts = [:]
            self.lastViewedAt = [:]
            for (index, card) in cards.enumerated() {
                let seeded = [36, 25, 18, 14, 12, 8, 4, 2]
                viewCounts[card.id] = seeded[safe: index] ?? max(1, 10 - index)
            }
            return
        }

        // 尝试从本地文件加载
        if let loaded = Self.loadCardsFromDisk(),
           !loaded.isEmpty {
            self.cards = loaded
            self.viewCounts = Self.loadViewCountsFromDisk() ?? [:]
            self.lastViewedAt = [:]
        } else {
            // 首次安装：使用内置种子数据
            let seed = KnowledgeCardLibrarySeed.makeCards()
            self.cards = seed
            self.viewCounts = [:]
            self.lastViewedAt = [:]
            for (index, card) in seed.enumerated() {
                let seeded = [36, 25, 18, 14, 12, 8, 4, 2, 6, 5, 4, 3, 2, 1, 1, 1, 1, 1, 1]
                viewCounts[card.id] = seeded[safe: index] ?? max(1, 20 - index)
            }
            UserDefaults.standard.set(Self.bundledSeedVersion, forKey: Self.bundledSeedVersionKey)
            saveToDisk()
        }

        applyBundledSeedIfNeeded()
        migrateEscapedControlSequencesIfNeeded()
    }

    func recordView(for card: KnowledgeCard) {
        let current = viewCounts[card.id] ?? 0
        viewCounts[card.id] = current + 1
        lastViewedAt[card.id] = Date()
        saveToDisk()
    }

    func recordView(forCardID id: UUID) {
        guard let card = cards.first(where: { $0.id == id }) else {
            return
        }
        recordView(for: card)
    }

    func addCard(_ card: KnowledgeCard) {
        cards.insert(card, at: 0)
        viewCounts[card.id] = 0
        saveToDisk()
    }

    func updateCard(_ card: KnowledgeCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        cards[index] = card
        saveToDisk()
    }

    func deleteCard(id: UUID) {
        cards.removeAll { $0.id == id }
        viewCounts.removeValue(forKey: id)
        lastViewedAt.removeValue(forKey: id)
        saveToDisk()
    }

    func deleteCards(ids: Set<UUID>) {
        guard !ids.isEmpty else {
            return
        }

        cards.removeAll { ids.contains($0.id) }
        ids.forEach { id in
            viewCounts.removeValue(forKey: id)
            lastViewedAt.removeValue(forKey: id)
        }
        saveToDisk()
    }

    func recentlyAdded(limit: Int) -> [KnowledgeCard] {
        cards
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func mostViewed(limit: Int) -> [KnowledgeCard] {
        cards
            .sorted { lhs, rhs in
                let lhsViews = viewCounts[lhs.id] ?? 0
                let rhsViews = viewCounts[rhs.id] ?? 0
                if lhsViews == rhsViews {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhsViews > rhsViews
            }
            .prefix(limit)
            .map { $0 }
    }

    var totalViews: Int {
        viewCounts.values.reduce(0, +)
    }

    var textModuleCount: Int { moduleCount(of: .text) }
    var imageModuleCount: Int { moduleCount(of: .image) }
    var codeModuleCount: Int { moduleCount(of: .code) }
    var linkModuleCount: Int { moduleCount(of: .link) }

    private func moduleCount(of kind: CardBlockKind) -> Int {
        cards.reduce(into: 0) { partial, card in
            partial += (card.modules ?? []).filter { $0.kind == kind }.count
        }
    }

    // Legacy counters kept for backward compatibility.
    var shortCardCount: Int {
        cards.count
    }

    var longCardCount: Int {
        0
    }

    var firstCollectDate: Date? {
        cards.map(\.createdAt).min()
    }

    var latestCollectDate: Date? {
        cards.map(\.createdAt).max()
    }

    func recentTags(limit: Int = 12) -> [String] {
        guard limit > 0 else {
            return []
        }

        let orderedCards = cards.sorted { lhs, rhs in
            max(lhs.updatedAt, lhs.createdAt) > max(rhs.updatedAt, rhs.createdAt)
        }

        var seen = Set<String>()
        var result: [String] = []

        for card in orderedCards {
            for rawTag in card.tags ?? [] {
                let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !tag.isEmpty else {
                    continue
                }

                let normalized = tag.lowercased()
                guard !seen.contains(normalized) else {
                    continue
                }

                seen.insert(normalized)
                result.append(tag)

                if result.count >= limit {
                    return result
                }
            }
        }

        return result
    }

    func allUniqueTags() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let orderedCards = cards.sorted { lhs, rhs in
            max(lhs.updatedAt, lhs.createdAt) > max(rhs.updatedAt, rhs.createdAt)
        }
        for card in orderedCards {
            for rawTag in card.tags ?? [] {
                let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !tag.isEmpty else { continue }
                let key = tag.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                result.append(tag)
            }
        }
        return result
    }

    // MARK: - Persistence

    private func migrateEscapedControlSequencesIfNeeded() {
        var didMutateAnyCard = false

        for cardIndex in cards.indices {
            var card = cards[cardIndex]

            card.type = .short

            var normalizedModules = card.modules ?? card.blocks ?? makeFallbackModules(from: card)
            if normalizedModules.isEmpty {
                normalizedModules = [CardBlock(kind: .text, moduleTitle: defaultModuleTitle(for: .text), text: "")]
            }

            for index in normalizedModules.indices {
                switch normalizedModules[index].kind {
                case .text:
                    if let text = normalizedModules[index].text {
                        normalizedModules[index].text =
                            ImportPayloadNormalizer.decodeEscapedControlSequencesDeterministically(text)
                    }
                case .code:
                    var snippets: [CodeSnippet] = []
                    if let existing = normalizedModules[index].codeSnippets, !existing.isEmpty {
                        snippets = existing
                    } else if let single = normalizedModules[index].codeSnippet {
                        snippets = [single]
                    }
                    if !snippets.isEmpty {
                        snippets = snippets.map { snippet in
                            var copy = snippet
                            copy.code = ImportPayloadNormalizer
                                .decodeEscapedControlSequencesDeterministically(snippet.code)
                            return copy
                        }
                        normalizedModules[index].codeSnippets = snippets
                        normalizedModules[index].codeSnippet = snippets.first
                    } else {
                        normalizedModules[index].codeSnippets = nil
                        normalizedModules[index].codeSnippet = nil
                    }
                case .image, .link:
                    if normalizedModules[index].kind == .image {
                        let sources = normalizedImageSources(from: normalizedModules[index], limit: 5)
                        normalizedModules[index].imageURLs = sources.isEmpty ? nil : sources
                        normalizedModules[index].imageURL = sources.first
                    }
                    if normalizedModules[index].kind == .link {
                        let entries = normalizedModules[index].linkItems
                            ?? (normalizedModules[index].linkItem.map { [$0] } ?? [])
                        let validEntries = entries.filter {
                            !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        normalizedModules[index].linkItems = validEntries.isEmpty ? nil : validEntries
                        normalizedModules[index].linkItem = validEntries.first
                    }
                    break
                case .formula:
                    if let text = normalizedModules[index].text {
                        normalizedModules[index].text =
                            ImportPayloadNormalizer.decodeEscapedControlSequencesDeterministically(text)
                    }
                }
                normalizedModules[index].moduleTitle = normalizeLegacyModuleTitle(
                    normalizedModules[index].moduleTitle,
                    for: normalizedModules[index].kind
                )
                if normalizedModules[index].moduleTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    switch normalizedModules[index].kind {
                    case .text: normalizedModules[index].moduleTitle = defaultModuleTitle(for: .text)
                    case .image: normalizedModules[index].moduleTitle = defaultModuleTitle(for: .image)
                    case .code: normalizedModules[index].moduleTitle = defaultModuleTitle(for: .code)
                    case .link: normalizedModules[index].moduleTitle = defaultModuleTitle(for: .link)
                    case .formula: normalizedModules[index].moduleTitle = defaultModuleTitle(for: .formula)
                    }
                }
            }

            card.modules = normalizedModules
            card.blocks = normalizedModules
            syncLegacyFields(from: normalizedModules, to: &card)

            cards[cardIndex] = card
            didMutateAnyCard = true
        }

        if didMutateAnyCard { saveToDisk() }
    }

    private func makeFallbackModules(from card: KnowledgeCard) -> [CardBlock] {
        var fallback: [CardBlock] = []
        let text = card.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            fallback.append(.text(card.content))
        }
        card.images?.forEach {
            fallback.append(.image($0, moduleTitle: defaultModuleTitle(for: .image)))
        }
        if let snippets = card.codeSnippets, !snippets.isEmpty {
            fallback.append(.codes(snippets, moduleTitle: defaultModuleTitle(for: .code)))
        }
        card.links?.forEach {
            fallback.append(
                CardBlock(kind: .link, moduleTitle: defaultModuleTitle(for: .link), linkItems: [$0])
            )
        }
        return fallback
    }

    private func syncLegacyFields(from modules: [CardBlock], to card: inout KnowledgeCard) {
        card.content = modules.first(where: { $0.kind == .text })?.text ?? ""

        let images = modules
            .filter { $0.kind == .image }
            .flatMap { normalizedImageSources(from: $0, limit: 5) }
        card.images = images.isEmpty ? nil : images

        let snippets = modules
            .filter { $0.kind == .code }
            .flatMap { block in
                if let multi = block.codeSnippets, !multi.isEmpty {
                    return multi
                }
                if let single = block.codeSnippet {
                    return [single]
                }
                return []
            }
            .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        card.codeSnippets = snippets.isEmpty ? nil : snippets

        let links = modules
            .filter { $0.kind == .link }
            .flatMap { block in
                if let items = block.linkItems, !items.isEmpty {
                    return items
                }
                if let item = block.linkItem {
                    return [item]
                }
                return []
            }
            .filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        card.links = links.isEmpty ? nil : links
    }

    private func normalizedImageSources(from block: CardBlock, limit: Int = 5) -> [String] {
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
        return Array(merged.prefix(max(limit, 0)))
    }

    private func defaultModuleTitle(for kind: CardBlockKind) -> String {
        switch kind {
        case .text: return "总结"
        case .image: return "图片"
        case .code: return "代码"
        case .link: return "链接"
        case .formula: return "公式"
        }
    }

    private func normalizeLegacyModuleTitle(_ title: String?, for kind: CardBlockKind) -> String? {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return title }
        switch kind {
        case .text:
            if trimmed == "文字" || trimmed == "文本" {
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
        }
        return title
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func applyBundledSeedIfNeeded() {
        let defaults = UserDefaults.standard
        let appliedVersion = defaults.string(forKey: Self.bundledSeedVersionKey)
        guard appliedVersion != Self.bundledSeedVersion else {
            return
        }

        var merged = cards
        var mergedViewCounts = viewCounts
        var mutated = false
        var insertedCount = 0

        for seedCard in KnowledgeCardLibrarySeed.makeCards() {
            let key = normalizedTitleKey(seedCard.title)
            if let index = merged.firstIndex(where: { normalizedTitleKey($0.title) == key }) {
                let existingCard = merged[index]
                let updatedCard = KnowledgeCard(
                    id: existingCard.id,
                    createdAt: existingCard.createdAt,
                    updatedAt: Date(),
                    title: seedCard.title,
                    content: seedCard.content,
                    type: seedCard.type,
                    images: seedCard.images,
                    codeSnippets: seedCard.codeSnippets,
                    links: seedCard.links,
                    tags: seedCard.tags,
                    themeColor: seedCard.themeColor,
                    modules: seedCard.modules,
                    blocks: seedCard.blocks
                )
                merged[index] = updatedCard
                mutated = true
            } else {
                merged.insert(seedCard, at: 0)
                mergedViewCounts[seedCard.id] = max(0, 4 - insertedCount)
                insertedCount += 1
                mutated = true
            }
        }

        cards = merged
        viewCounts = mergedViewCounts
        defaults.set(Self.bundledSeedVersion, forKey: Self.bundledSeedVersionKey)
        if mutated {
            saveToDisk()
        }
    }

    private func normalizedTitleKey(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        // 保存卡片
        if let data = try? encoder.encode(cards) {
            let url = Self.documentsDirectory.appendingPathComponent(Self.cardsFileName)
            try? data.write(to: url, options: .atomic)
        }

        // 保存浏览计数
        let countDict = viewCounts.reduce(into: [String: Int]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        if let data = try? encoder.encode(countDict) {
            let url = Self.documentsDirectory.appendingPathComponent(Self.viewCountsFileName)
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func loadCardsFromDisk() -> [KnowledgeCard]? {
        let url = documentsDirectory.appendingPathComponent(cardsFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([KnowledgeCard].self, from: data)
    }

    private static func loadViewCountsFromDisk() -> [UUID: Int]? {
        let url = documentsDirectory.appendingPathComponent(viewCountsFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return nil }
        return dict.reduce(into: [UUID: Int]()) { result, pair in
            if let uuid = UUID(uuidString: pair.key) {
                result[uuid] = pair.value
            }
        }
    }
}

// MARK: - Seed Data (Prompt-aligned JSON samples)
private enum KnowledgeCardLibrarySeed {
    static func makeCards() -> [KnowledgeCard] {
        let payloads = makePromptStylePayloads()
        return payloads.compactMap { payload in
            guard let json = try? JSONSerialization.data(
                withJSONObject: ImportPayloadNormalizer.normalizeCardPayload(payload)
            ) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(KnowledgeCard.self, from: json)
        }
    }

    private static func makePromptStylePayloads() -> [[String: Any]] {
        let now = Date()
        let cal = Calendar.current
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        func ts(day: Int, hour: Int = 0) -> String {
            let dayDate = cal.date(byAdding: .day, value: day, to: now) ?? now
            let final = cal.date(byAdding: .hour, value: hour, to: dayDate) ?? dayDate
            return formatter.string(from: final)
        }

        return [
            [
                "createdAt": ts(day: -1, hour: -5),
                "updatedAt": ts(day: -1, hour: -2),
                "title": "Git中的Commit命令是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "`git commit` 会把暂存区（Staging Area）的改动固化为一个可追踪的提交版本。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "`git commit` 的输入是暂存区而不是工作区，因此在执行前通常先 `git add` 指定本次提交范围。\n\n核心要点：\n\n- 每次 commit 会生成一个唯一的 SHA-1 哈希值，作为版本标识\n- 高质量提交建议做到“语义单一、信息清晰、粒度可回滚”\n- 提交信息推荐使用约定式格式，如 `feat:` `fix:` `docs:` 等前缀\n\n常用操作：\n\n1. `git commit -m \"message\"` — 直接附带提交信息\n2. `git commit --amend` — 修正最近一次提交（补漏文件或修改信息）\n3. `git commit -a` — 跳过 add 步骤，直接提交所有已跟踪文件的改动\n\n> 注意：`--amend` 会改写提交历史（hash 变化），已推送到远程的提交慎用。"
                    ],
                    [
                        "type": "code",
                        "title": "代码示例",
                        "snippets": [
                            [
                                "name": "基础提交流程",
                                "language": "bash",
                                "code": "git add src/login.swift\ngit commit -m \"feat: add login validation\""
                            ],
                            [
                                "name": "修正最近一次提交",
                                "language": "bash",
                                "code": "git add src/login.swift\ngit commit --amend --no-edit"
                            ]
                        ]
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://git-scm.com/docs/git-commit", "title": "Git 官方文档：git-commit"]
                        ]
                    ]
                ],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -2, hour: -4),
                "updatedAt": ts(day: -2, hour: -1),
                "title": "Git中的Add命令是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "`git add` 用来把工作区改动加入暂存区（Staging Area），决定“下一次 commit 提交什么”。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "`git add` 是 Git 工作流中最基础的命令之一，它控制的是“哪些改动进入下一次提交”。\n\n常见用法：\n\n- `git add <文件>` — 精确添加指定文件\n- `git add .` — 添加当前目录下所有改动\n- `git add -p` — 交互式选择改动块（适合做精细提交）\n\n撤销误添加：\n\n- `git restore --staged <file>` — 将文件从暂存区移回工作区\n- `git reset HEAD <file>` — 旧版 Git 的等效操作\n\n> 多人协作时，先精确 add 再 commit 能显著降低回滚与代码审查成本。一次 commit 只做一件事是最佳实践。"
                    ],
                    [
                        "type": "code",
                        "title": "代码示例",
                        "snippets": [
                            [
                                "name": "精确选择暂存内容",
                                "language": "bash",
                                "code": "git add -p\ngit status -sb"
                            ],
                            [
                                "name": "取消误暂存文件",
                                "language": "bash",
                                "code": "git add src/config.swift\ngit restore --staged src/config.swift"
                            ]
                        ]
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://git-scm.com/docs/git-add", "title": "Git 官方文档：git-add"]
                        ]
                    ]
                ],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -3, hour: -4),
                "updatedAt": ts(day: -3, hour: -1),
                "title": "Git中的Push命令是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "`git push` 会把本地分支的提交上传到远程仓库，供协作方拉取和审阅。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "`git push` 用于将本地完成的工作同步到远程仓库（如 GitHub、GitLab）。\n\n基本流程：\n\n1. 在本地完成开发并 commit\n2. 使用 `git push` 将提交推送到远程分支\n3. 协协作者通过 pull 获取你的更新\n\n首次推送注意事项：\n\n- 第一次推送新分支需绑定上游：`git push --set-upstream origin <分支名>`\n- 之后在同一分支上可以直接 `git push`\n\n推送失败的常见原因：\n\n- 远程比本地新 → 先 `git pull` 再推送\n- 分支保护规则 → 需通过 PR/MR 合并\n\n> 强推（`--force`）会覆盖远程历史，应优先使用更安全的 `--force-with-lease`。"
                    ],
                    [
                        "type": "code",
                        "title": "代码示例",
                        "snippets": [
                            [
                                "name": "首次推送建立上游",
                                "language": "bash",
                                "code": "git push --set-upstream origin feature/login-ui"
                            ],
                            [
                                "name": "更安全的强推",
                                "language": "bash",
                                "code": "git push --force-with-lease origin feature/login-ui"
                            ]
                        ]
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://git-scm.com/docs/git-push", "title": "Git 官方文档：git-push"]
                        ]
                    ]
                ],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -4, hour: -3),
                "updatedAt": ts(day: -4, hour: -1),
                "title": "Git中的Pull命令是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "`git pull` 用于把远程分支最新提交拉到本地并自动整合，本质是 `fetch + merge`。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "`git pull` 是日常协作中使用频率最高的远程同步命令。\n\n两种整合策略：\n\n- **Merge 模式**（默认）：产生一个合并提交，保留完整分支历史\n- **Rebase 模式**（`git pull --rebase`）：将本地提交“重放”在远程之上，历史更线性\n\n冲突处理步骤：\n\n1. Git 提示哪些文件存在冲突\n2. 手动编辑冲突文件，选择保留的内容\n3. `git add` 标记已解决\n4. 完成合并（merge：`git commit`；rebase：`git rebase --continue`）\n\n> 团队应统一 pull 策略。混用 merge 和 rebase 会导致提交历史风格不一致。"
                    ],
                    [
                        "type": "code",
                        "title": "代码示例",
                        "snippets": [
                            [
                                "name": "默认合并式拉取",
                                "language": "bash",
                                "code": "git switch main\ngit pull origin main"
                            ],
                            [
                                "name": "线性历史拉取",
                                "language": "bash",
                                "code": "git switch feature/login-ui\ngit pull --rebase origin main"
                            ]
                        ]
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://git-scm.com/docs/git-pull", "title": "Git 官方文档：git-pull"]
                        ]
                    ]
                ],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -5, hour: -3),
                "updatedAt": ts(day: -5, hour: -1),
                "title": "Git中的Rebase命令是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "`git rebase` 会把当前分支提交“重新安放”到新的基底上，形成更线性的提交历史。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "`git rebase` 适合在功能分支上同步主线最新提交，避免产生无意义的 merge commit。\n\n工作原理：\n\n- 找到当前分支和目标分支的共同祖先\n- 将当前分支从祖先之后的提交“摘下来”\n- 以目标分支最新提交为新基底，逐个重新应用\n\n这意味着提交的 hash 值会改变，因此：\n\n- ✅ 适合对本地未推送的功能分支使用\n- ❌ 不建议对已共享的公共分支执行\n\n交互式 rebase（`git rebase -i`）可以：\n\n- 合并多个小提交为一个\n- 修改提交信息\n- 重新排列提交顺序\n- 删除不需要的提交\n\n> 出现冲突时按提示逐个解决，然后执行 `git rebase --continue` 继续。"
                    ],
                    [
                        "type": "code",
                        "title": "代码示例",
                        "snippets": [
                            [
                                "name": "同步主线并整理提交",
                                "language": "bash",
                                "code": "git fetch origin\ngit switch feature/login-ui\ngit rebase origin/main"
                            ],
                            [
                                "name": "交互式整理提交历史",
                                "language": "bash",
                                "code": "git rebase -i HEAD~4"
                            ]
                        ]
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://git-scm.com/docs/git-rebase", "title": "Git 官方文档：git-rebase"]
                        ]
                    ]
                ],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -6, hour: -2),
                "updatedAt": ts(day: -6, hour: -1),
                "title": "维生素A的作用是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "维生素A主要帮助视觉功能、免疫防御和皮肤黏膜健康。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "维生素A是一种脂溶性维生素，在人体内有多种重要功能。\n\n主要生理作用：\n\n- **视觉功能**：参与视网膜感光色素（视紫红质）的合成，缺乏时常见夜间视力下降\n- **免疫屏障**：维持上皮细胞分化和黏膜完整性，增强抵抗感染的能力\n- **皮肤健康**：促进皮肤细胞正常代谢，缺乏时皮肤容易干燥粗糙\n\n常见食物来源：\n\n- 动物性来源：肝脏、蛋黄、乳制品（直接含有视黄醇）\n- 植物性来源：胡萝卜、南瓜、菠菜等深色蔬果（含 β-胡萝卜素，体内转化为维生素A）\n\n> 维生素A为脂溶性，长期高剂量补充可能蓄积中毒，尤其孕期需遵循专业建议。日常优先通过饮食摄入。"
                    ],
                    [
                        "type": "formula",
                        "title": "化学式",
                        "content": "C_{20}H_{30}O"
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://ods.od.nih.gov/factsheets/VitaminA-Consumer/", "title": "NIH ODS：Vitamin A Fact Sheet"]
                        ]
                    ]
                ],
                "tags": ["健康"]
            ],
            [
                "createdAt": ts(day: -7, hour: -2),
                "updatedAt": ts(day: -7, hour: -1),
                "title": "维生素B的作用是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "维生素B族是一组功能互补的水溶性维生素，主要参与能量代谢、神经传导和造血过程。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "维生素B族不是单一营养素，而是包含 8 种成员的大家族。\n\n各成员主要功能：\n\n- **B1（硫胺素）**：碳水化合物代谢的辅酶，缺乏可导致脚气病\n- **B2（核黄素）**：参与能量代谢，缺乏时常见口角炎\n- **B6（吡哆醇）**：氨基酸代谢和神经递质合成\n- **B12（钴胺素）**：红细胞生成和神经系统维护，素食者容易缺乏\n- **叶酸（B9）**：DNA 合成和细胞分裂，孕期尤为重要\n\n容易缺乏的人群：\n\n- 长期饮食结构单一者\n- 极端节食或纯素食者\n- 有特殊吸收问题的人群（如胃肠疾病患者）\n\n> B族维生素为水溶性，体内不易蓄积，但补充策略仍应先评估再定量，建议咨询专业人士。"
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://ods.od.nih.gov/factsheets/VitaminB12-Consumer/", "title": "NIH ODS：Vitamin B12 Fact Sheet"]
                        ]
                    ]
                ],
                "tags": ["健康"]
            ],
            [
                "createdAt": ts(day: -8, hour: -2),
                "updatedAt": ts(day: -8, hour: -1),
                "title": "维生素C的作用是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "维生素C核心作用是抗氧化、促进胶原合成并帮助非血红素铁的吸收。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "维生素C（抗坏血酸，Ascorbic Acid）是人体必需的水溶性维生素，无法自行合成。\n\n三大核心功能：\n\n1. **抗氧化**：清除自由基，保护细胞免受氧化损伤\n2. **胶原蛋白合成**：对皮肤、血管和创伤修复至关重要\n3. **促进铁吸收**：帮助植物性食物中的非血红素铁转化为可吸收形式\n\n常见食物来源：\n\n- 柑橘类水果（橙子、柠檬）\n- 猕猴桃、草莓\n- 青椒、西兰花\n\n例如，一个中等大小的橙子约含 70mg 维生素C，基本可满足成人日推荐量。\n\n> 日常建议优先通过饮食摄入。长期高剂量补充（>2000mg/天）可能引起胃肠不适，具体方案建议咨询医生。"
                    ],
                    [
                        "type": "formula",
                        "title": "化学式",
                        "content": "C_6H_8O_6"
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://ods.od.nih.gov/factsheets/VitaminC-Consumer/", "title": "NIH ODS：Vitamin C Fact Sheet"]
                        ]
                    ]
                ],
                "tags": ["健康"]
            ],
            [
                "createdAt": ts(day: -9, hour: -2),
                "updatedAt": ts(day: -9, hour: -1),
                "title": "维生素D的作用是什么？",
                "modules": [
                    [
                        "type": "text",
                        "title": "总结",
                        "content": "维生素D主要帮助钙磷吸收，支持骨骼健康、肌肉功能和免疫调节。"
                    ],
                    [
                        "type": "text",
                        "title": "主要内容",
                        "content": "维生素D是一种脂溶性维生素，也被称为“阳光维生素”，因为人体可通过日照在皮肤中合成。\n\n主要生理作用：\n\n- **钙磷代谢**：促进小肠对钙和磷的吸收，维持骨密度\n- **肌肉功能**：影响肌肉收缩和平衡能力，缺乏时易跌倒\n- **免疫调节**：参与先天和适应性免疫应答\n\n获取途径：\n\n- 日照合成（每天 15-20 分钟中等强度阳光照射）\n- 食物来源：深海鱼类（三文鱼、沙丁鱼）、蛋黄、强化牛奶\n- 膳食补充剂（维生素D3 效果优于 D2）\n\n容易缺乏的人群：\n\n- 久居室内、日照不足者\n- 老年人（皮肤合成能力下降）\n- 深肤色人群（黑色素阻碍紫外线吸收）\n\n> 补充不宜盲目超量，建议通过血液检测 25(OH)D 水平后再制定方案，并遵循专业建议。"
                    ],
                    [
                        "type": "link",
                        "title": "参考链接",
                        "links": [
                            ["url": "https://ods.od.nih.gov/factsheets/VitaminD-Consumer/", "title": "NIH ODS：Vitamin D Fact Sheet"]
                        ]
                    ]
                ],
                "tags": ["健康"]
            ]
        ]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}
