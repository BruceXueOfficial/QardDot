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
    private static let bundledSeedVersion = "2026-02-git-vitamin-v3-prompt-titles"

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
        case .text: return "文本"
        case .image: return "图片"
        case .code: return "代码"
        case .link: return "链接"
        }
    }

    private func normalizeLegacyModuleTitle(_ title: String?, for kind: CardBlockKind) -> String? {
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

        let existingTitleKeys = Set(cards.map { normalizedTitleKey($0.title) })
        var merged = cards
        var mergedViewCounts = viewCounts
        var inserted = 0

        for seedCard in KnowledgeCardLibrarySeed.makeCards() {
            let key = normalizedTitleKey(seedCard.title)
            guard !existingTitleKeys.contains(key) else {
                continue
            }
            merged.insert(seedCard, at: 0)
            mergedViewCounts[seedCard.id] = max(0, 4 - inserted)
            inserted += 1
        }

        cards = merged
        viewCounts = mergedViewCounts
        defaults.set(Self.bundledSeedVersion, forKey: Self.bundledSeedVersionKey)
        if inserted > 0 {
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

        let promptModuleLayout: [String: String] = [
            "text": "split",
            "code": "group",
            "link": "group",
            "image": "split"
        ]
        let promptModuleTitles: [String: Any] = [
            "text": ["总结", "详细说明"],
            "code": "代码示例",
            "link": "参考链接",
            "image": "相关图片"
        ]

        return [
            [
                "createdAt": ts(day: -1, hour: -5),
                "updatedAt": ts(day: -1, hour: -2),
                "title": "Git中的Commit命令是什么？",
                "content": [
                    "### 直接结论\n`git commit` 会把暂存区的改动固化为一个可追踪的提交版本。",
                    "`git commit` 的输入是暂存区（staging area）而不是工作区，因此在执行前通常先 `git add` 指定本次提交范围。高质量提交建议做到“语义单一、信息清晰、粒度可回滚”。若需要补漏文件或修改提交信息，可使用 `git commit --amend` 修正最近一次提交。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=git%20commit%20%E6%95%99%E7%A8%8B", "title": "Bilibili：Git commit 实战教程"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=git%20commit", "title": "小红书：Git commit 使用经验"],
                    ["url": "https://www.douyin.com/search/Git%20commit", "title": "抖音：Git commit 常见误区"],
                    ["url": "https://git-scm.com/docs/git-commit", "title": "Git 官方文档：git-commit"]
                ],
                "codeSnippets": [
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
                ],
                "images": [],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -2, hour: -4),
                "updatedAt": ts(day: -2, hour: -1),
                "title": "Git中的Add命令是什么？",
                "content": [
                    "### 直接结论\n`git add` 用来把工作区改动加入暂存区，决定“下一次 commit 提交什么”。",
                    "`git add` 支持按文件、按目录、按交互块（`-p`）选择改动，适合做小而清晰的提交。多人协作时，先精确 add 再 commit 能显著降低回滚与代码审查成本。若误加文件，可通过 `git restore --staged <file>` 取消暂存。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=git%20add%20-p", "title": "Bilibili：Git add -p 分块暂存教程"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=git%20add", "title": "小红书：Git add 常用姿势"],
                    ["url": "https://www.douyin.com/search/Git%20add", "title": "抖音：Git add 使用讲解"],
                    ["url": "https://git-scm.com/docs/git-add", "title": "Git 官方文档：git-add"]
                ],
                "codeSnippets": [
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
                ],
                "images": [],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -3, hour: -4),
                "updatedAt": ts(day: -3, hour: -1),
                "title": "Git中的Push命令是什么？",
                "content": [
                    "### 直接结论\n`git push` 会把本地分支提交上传到远程仓库，供协作方拉取和审阅。",
                    "`git push` 常见于功能分支提交流程。首次推送建议用 `--set-upstream` 绑定跟踪分支，后续可直接 `git push`。如果远程比本地新，推送会被拒绝，需要先拉取并整合差异，再重新推送。强推（`--force`）应谨慎使用，优先考虑 `--force-with-lease`。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=git%20push%20%E5%A4%B1%E8%B4%A5", "title": "Bilibili：Git push 被拒处理教程"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=git%20push", "title": "小红书：Git push 实战笔记"],
                    ["url": "https://www.douyin.com/search/Git%20push", "title": "抖音：Git push 常见问题"],
                    ["url": "https://git-scm.com/docs/git-push", "title": "Git 官方文档：git-push"]
                ],
                "codeSnippets": [
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
                ],
                "images": [],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -4, hour: -3),
                "updatedAt": ts(day: -4, hour: -1),
                "title": "Git中的Pull命令是什么？",
                "content": [
                    "### 直接结论\n`git pull` 用于把远程分支最新提交拉到本地并自动整合。",
                    "`git pull` 本质是 `fetch + merge/rebase`。默认策略通常是 merge，也可配置为 rebase（`git pull --rebase`）以保持线性历史。遇到冲突时要先解决冲突并完成继续操作，再推送到远程。团队应统一 pull 策略，避免历史风格混乱。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=git%20pull%20rebase", "title": "Bilibili：Git pull 与 rebase 讲解"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=git%20pull", "title": "小红书：Git pull 冲突处理经验"],
                    ["url": "https://www.douyin.com/search/Git%20pull", "title": "抖音：Git pull 快速上手"],
                    ["url": "https://git-scm.com/docs/git-pull", "title": "Git 官方文档：git-pull"]
                ],
                "codeSnippets": [
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
                ],
                "images": [],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -5, hour: -3),
                "updatedAt": ts(day: -5, hour: -1),
                "title": "Git中的Rebase命令是什么？",
                "content": [
                    "### 直接结论\n`git rebase` 会把当前分支提交“重新安放”到新的基底上，形成更线性的历史。",
                    "`git rebase` 适合在功能分支上同步主线最新提交，减少无意义 merge commit。它会改写提交历史（commit hash 会变化），因此不建议对已共享的公共分支随意 rebase。出现冲突时可按提示逐个解决并执行 `git rebase --continue`。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=git%20rebase%20%E6%95%99%E7%A8%8B", "title": "Bilibili：Git rebase 实战教程"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=git%20rebase", "title": "小红书：Git rebase 使用经验"],
                    ["url": "https://www.douyin.com/search/Git%20rebase", "title": "抖音：Git rebase 冲突处理"],
                    ["url": "https://git-scm.com/docs/git-rebase", "title": "Git 官方文档：git-rebase"]
                ],
                "codeSnippets": [
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
                ],
                "images": [],
                "tags": ["Git", "编程"]
            ],
            [
                "createdAt": ts(day: -6, hour: -2),
                "updatedAt": ts(day: -6, hour: -1),
                "title": "维生素A的作用是什么？",
                "content": [
                    "### 直接结论\n维生素A主要帮助视觉功能、免疫防御和皮肤黏膜健康。",
                    "维生素A参与视网膜感光过程，缺乏时常见夜间视力下降；它也参与免疫屏障和上皮细胞分化，对皮肤和黏膜完整性很重要。常见来源包括动物肝脏、蛋黄、乳制品，以及富含胡萝卜素的深色蔬果。补充应避免长期高剂量，尤其孕期需遵循专业建议。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0A%20%E4%BD%9C%E7%94%A8", "title": "Bilibili：维生素A 作用与缺乏表现"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0A", "title": "小红书：维生素A 饮食补充经验"],
                    ["url": "https://www.douyin.com/search/%E7%BB%B4%E7%94%9F%E7%B4%A0A", "title": "抖音：维生素A 科普短视频"],
                    ["url": "https://ods.od.nih.gov/factsheets/VitaminA-Consumer/", "title": "NIH ODS：Vitamin A Fact Sheet"]
                ],
                "codeSnippets": [],
                "images": [],
                "tags": ["健康"]
            ],
            [
                "createdAt": ts(day: -7, hour: -2),
                "updatedAt": ts(day: -7, hour: -1),
                "title": "维生素B的作用是什么？",
                "content": [
                    "### 直接结论\n维生素B族主要参与能量代谢、神经系统和造血相关过程。",
                    "维生素B族并不是单一营养素，而是一组功能互补的成员，如 B1、B2、B6、B12 与叶酸。它们广泛参与碳水、脂肪和蛋白质代谢，也与神经传导和造血过程密切相关。长期饮食结构单一、极端节食或特殊吸收问题人群更容易出现不足，补充策略应先评估再定量。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0B%E6%97%8F%20%E4%BD%9C%E7%94%A8", "title": "Bilibili：维生素B族全景讲解"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0B%E6%97%8F", "title": "小红书：维生素B族补充经验贴"],
                    ["url": "https://www.douyin.com/search/%E7%BB%B4%E7%94%9F%E7%B4%A0B%E6%97%8F", "title": "抖音：维生素B族 科普视频"],
                    ["url": "https://ods.od.nih.gov/factsheets/VitaminB12-Consumer/", "title": "NIH ODS：Vitamin B12 Fact Sheet"]
                ],
                "codeSnippets": [],
                "images": [],
                "tags": ["健康"]
            ],
            [
                "createdAt": ts(day: -8, hour: -2),
                "updatedAt": ts(day: -8, hour: -1),
                "title": "维生素C的作用是什么？",
                "content": [
                    "### 直接结论\n维生素C核心作用是抗氧化、促进胶原合成并帮助铁吸收。",
                    "维生素C参与胶原蛋白合成，对皮肤、血管和创伤修复有帮助；它还是重要的抗氧化营养素，并能促进非血红素铁吸收。常见食物来源包括柑橘、猕猴桃、草莓、青椒和西兰花。日常建议优先饮食摄入，长期高剂量补充需注意胃肠不适和个体差异。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0C%20%E4%BD%9C%E7%94%A8", "title": "Bilibili：维生素C 作用与补充建议"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0C", "title": "小红书：维生素C 使用体验与误区"],
                    ["url": "https://www.douyin.com/search/%E7%BB%B4%E7%94%9F%E7%B4%A0C", "title": "抖音：维生素C 科普视频"],
                    ["url": "https://ods.od.nih.gov/factsheets/VitaminC-Consumer/", "title": "NIH ODS：Vitamin C Fact Sheet"]
                ],
                "codeSnippets": [],
                "images": [],
                "tags": ["健康"]
            ],
            [
                "createdAt": ts(day: -9, hour: -2),
                "updatedAt": ts(day: -9, hour: -1),
                "title": "维生素D的作用是什么？",
                "content": [
                    "### 直接结论\n维生素D主要帮助钙磷吸收，支持骨骼、肌肉和免疫功能。",
                    "维生素D有助于钙和磷吸收，与骨密度、肌肉功能及免疫调节相关。其来源包括日照合成、鱼类、蛋黄及强化食品。对久居室内、日照不足或特定人群，评估后补充会更稳妥。补充不宜盲目超量，建议结合检测结果和专业建议制定方案。"
                ],
                "moduleTitles": promptModuleTitles,
                "moduleLayout": promptModuleLayout,
                "links": [
                    ["url": "https://search.bilibili.com/all?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0D%20%E4%BD%9C%E7%94%A8", "title": "Bilibili：维生素D 与骨骼健康"],
                    ["url": "https://www.xiaohongshu.com/search_result?keyword=%E7%BB%B4%E7%94%9F%E7%B4%A0D", "title": "小红书：维生素D 补充经验与剂量讨论"],
                    ["url": "https://www.douyin.com/search/%E7%BB%B4%E7%94%9F%E7%B4%A0D", "title": "抖音：维生素D 科普短视频"],
                    ["url": "https://ods.od.nih.gov/factsheets/VitaminD-Consumer/", "title": "NIH ODS：Vitamin D Fact Sheet"]
                ],
                "codeSnippets": [],
                "images": [],
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
