import Foundation
import SwiftUI
import Testing
@testable import 知点

struct KnowledgeCardTests {
    @Test
    func chatBubbleRendererStripsMarkdownSyntaxFromCopiedText() {
        let message = ChatMessage(
            content: "### 标题\n- 第一项\n- 第二项\n[链接](https://example.com)\n`代码`",
            type: .ai
        )

        let rendered = ChatBubbleTextRenderer
            .renderedText(for: message, colorScheme: .light)
            .string

        #expect(rendered.contains("标题"))
        #expect(rendered.contains("第一项"))
        #expect(rendered.contains("第二项"))
        #expect(rendered.contains("链接"))
        #expect(rendered.contains("代码"))
        #expect(!rendered.contains("###"))
        #expect(!rendered.contains("[链接]"))
        #expect(!rendered.contains("https://example.com"))
        #expect(!rendered.contains("`代码`"))
    }

    @Test
    func aiChatCompletionMessageUsesAllExpectedTemplates() {
        let expected = [
            "已经为您生成 3 张卡片，可点击左下角查看详情。",
            "本轮已为您整理出 3 张卡片，可点击左下角查看详情。",
            "已根据刚才的对话生成 3 张卡片，可点击左下角查看详情。",
            "卡片已经生成完成，本次共为您准备了 3 张卡片，可点击左下角查看详情。",
            "已为您提炼出 3 张卡片，可点击左下角查看详情。"
        ]

        for (index, message) in expected.enumerated() {
            #expect(AiChatViewModel.cardGenerationCompletionMessage(cardCount: 3, randomIndex: index) == message)
        }
    }

    @Test
    func aiChatDisplayedCharacterCountCatchesUpUsingElapsedTime() {
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(
            AiChatViewModel.displayedCharacterCount(
                forBufferCount: 120,
                typingStartTime: start,
                now: start.addingTimeInterval(-0.2)
            ) == 0
        )

        #expect(
            AiChatViewModel.displayedCharacterCount(
                forBufferCount: 120,
                typingStartTime: start,
                now: start.addingTimeInterval(2)
            ) == 75
        )

        #expect(
            AiChatViewModel.displayedCharacterCount(
                forBufferCount: 20,
                typingStartTime: start,
                now: start.addingTimeInterval(10)
            ) == 20
        )
    }

    @Test
    func defaultTypeIsShort() {
        let card = KnowledgeCard(title: "Title", content: "Content")
        #expect(card.type == .short)
    }

    @Test
    func touchUpdatedAtRefreshesTimestamp() {
        let oldDate = Date(timeIntervalSince1970: 0)
        var card = KnowledgeCard(
            updatedAt: oldDate,
            title: "Title",
            content: "Content"
        )

        card.touchUpdatedAt()

        #expect(card.updatedAt > oldDate)
    }

    @MainActor
    @Test
    func cardThemeColorEncodingRoundTripPreservesSelectedValue() throws {
        let encoded = try JSONEncoder().encode(CardThemeColor.green)
        let decoded = try JSONDecoder().decode(CardThemeColor.self, from: encoded)
        #expect(decoded == .green)
    }

    @MainActor
    @Test
    func cardThemeColorDecodingFallsBackToDefaultWhenUnknown() throws {
        let raw = "\"unknown-theme\""
        let data = try #require(raw.data(using: .utf8))
        let decoded = try JSONDecoder().decode(CardThemeColor.self, from: data)
        #expect(decoded == .defaultTheme)
    }

    @MainActor
    @Test
    func updateThemeColorUsesUserSelection() {
        let viewModel = KnowledgeCardViewModel(
            card: KnowledgeCard(
                title: "Title",
                content: "Content"
            )
        )

        viewModel.updateThemeColor(.orange)

        #expect(viewModel.card.themeColor == .orange)
    }

    @Test
    func cardThemeColorDecodingMapsLegacyValues() throws {
        #expect(try decodeTheme("nightBlue") == .blue)
        #expect(try decodeTheme("nightTeal") == .green)
        #expect(try decodeTheme("forestNight") == .green)
        #expect(try decodeTheme("graphite") == .purple)
        #expect(try decodeTheme("mist") == .purple)
    }

    @Test
    func prefersLightForegroundUsesColorScheme() {
        for theme in CardThemeColor.allCases {
            #expect(theme.prefersLightForeground(in: .dark))
            #expect(!theme.prefersLightForeground(in: .light))
        }
    }

    private func decodeTheme(_ raw: String) throws -> CardThemeColor {
        let data = try #require("\"\(raw)\"".data(using: .utf8))
        return try JSONDecoder().decode(CardThemeColor.self, from: data)
    }

    @Test
    func importFallbackSupportsSplitAndGroupedLayouts() {
        let payload: [String: Any] = [
            "title": "Layout Fallback",
            "content": ["第一段", "第二段"],
            "images": [
                "https://example.com/a.png",
                "https://example.com/b.png"
            ],
            "codeSnippets": [
                ["name": "A", "language": "Swift", "code": "print(1)"],
                ["name": "B", "language": "Swift", "code": "print(2)"]
            ],
            "links": [
                ["url": "https://example.com/a", "title": "A"],
                ["url": "https://example.com/b", "title": "B"]
            ],
            "moduleLayout": [
                "text": "split",
                "image": "group",
                "code": "group",
                "link": "group"
            ]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let modules = (normalized["modules"] as? [[String: Any]]) ?? []

        #expect(modules.count == 5)
        #expect(modules.filter { ($0["kind"] as? String) == "text" }.count == 2)
        #expect(modules.filter { ($0["kind"] as? String) == "image" }.count == 1)
        #expect(modules.filter { ($0["kind"] as? String) == "code" }.count == 1)
        #expect(modules.filter { ($0["kind"] as? String) == "link" }.count == 1)

        let groupedImageCount = (modules.first { ($0["kind"] as? String) == "image" }?["imageURLs"] as? [String])?.count ?? 0
        let groupedCodeCount = (modules.first { ($0["kind"] as? String) == "code" }?["codeSnippets"] as? [[String: Any]])?.count ?? 0
        let groupedLinkCount = (modules.first { ($0["kind"] as? String) == "link" }?["linkItems"] as? [[String: Any]])?.count ?? 0

        #expect(groupedImageCount == 2)
        #expect(groupedCodeCount == 2)
        #expect(groupedLinkCount == 2)
    }

    @Test
    func importExplicitModulesSupportSplitIntoBlocks() {
        let payload: [String: Any] = [
            "title": "Split Modules",
            "modules": [
                [
                    "kind": "text",
                    "texts": ["一段", "二段"],
                    "splitIntoBlocks": true
                ],
                [
                    "kind": "code",
                    "codeSnippets": [
                        ["name": "C1", "language": "Swift", "code": "print(\"1\")"],
                        ["name": "C2", "language": "Swift", "code": "print(\"2\")"]
                    ],
                    "splitIntoBlocks": true
                ],
                [
                    "kind": "link",
                    "linkItems": [
                        ["url": "https://example.com/1", "title": "L1"],
                        ["url": "https://example.com/2", "title": "L2"]
                    ],
                    "splitIntoBlocks": true
                ],
                [
                    "kind": "image",
                    "imageURLs": [
                        "https://example.com/1.png",
                        "https://example.com/2.png"
                    ],
                    "splitIntoBlocks": true
                ]
            ]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let modules = (normalized["modules"] as? [[String: Any]]) ?? []

        #expect(modules.count == 8)
        #expect(modules.filter { ($0["kind"] as? String) == "text" }.count == 2)
        #expect(modules.filter { ($0["kind"] as? String) == "code" }.count == 2)
        #expect(modules.filter { ($0["kind"] as? String) == "link" }.count == 2)
        #expect(modules.filter { ($0["kind"] as? String) == "image" }.count == 2)
    }

    @Test
    func importExplicitPluralFieldsDefaultToGroupedBlocks() {
        let payload: [String: Any] = [
            "title": "Grouped Modules",
            "modules": [
                [
                    "kind": "text",
                    "texts": ["一段", "二段"]
                ],
                [
                    "kind": "code",
                    "codeSnippets": [
                        ["name": "C1", "language": "Swift", "code": "print(1)"],
                        ["name": "C2", "language": "Swift", "code": "print(2)"]
                    ]
                ],
                [
                    "kind": "link",
                    "linkItems": [
                        ["url": "https://example.com/a", "title": "A"],
                        ["url": "https://example.com/b", "title": "B"]
                    ]
                ],
                [
                    "kind": "image",
                    "imageURLs": [
                        "https://example.com/a.png",
                        "https://example.com/b.png"
                    ]
                ]
            ]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let modules = (normalized["modules"] as? [[String: Any]]) ?? []

        #expect(modules.count == 4)
        #expect((modules.first { ($0["kind"] as? String) == "text" }?["text"] as? String)?.contains("一段") == true)
        #expect(((modules.first { ($0["kind"] as? String) == "code" }?["codeSnippets"] as? [[String: Any]])?.count ?? 0) == 2)
        #expect(((modules.first { ($0["kind"] as? String) == "link" }?["linkItems"] as? [[String: Any]])?.count ?? 0) == 2)
        #expect(((modules.first { ($0["kind"] as? String) == "image" }?["imageURLs"] as? [String])?.count ?? 0) == 2)
    }

    @Test
    func importSupportsModuleTitlesForEachBlock() {
        let payload: [String: Any] = [
            "title": "Module Titles",
            "content": [
                "### 一句话",
                "详细说明"
            ],
            "moduleLayout": [
                "text": "split",
                "code": "group",
                "link": "group",
                "image": "split"
            ],
            "moduleTitles": [
                "text": ["一句话总结", "详细说明"],
                "code": "代码示例",
                "link": "参考链接",
                "image": "配图"
            ],
            "codeSnippets": [
                ["name": "S1", "language": "bash", "code": "echo 1"],
                ["name": "S2", "language": "bash", "code": "echo 2"]
            ],
            "links": [
                ["url": "https://example.com/1", "title": "L1"],
                ["url": "https://example.com/2", "title": "L2"]
            ],
            "images": [
                "https://example.com/1.png",
                "https://example.com/2.png"
            ]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let modules = (normalized["modules"] as? [[String: Any]]) ?? []

        #expect(modules.count == 6)
        let textModules = modules.filter { ($0["kind"] as? String) == "text" }
        #expect((textModules.first?["moduleTitle"] as? String) == "一句话总结")
        #expect((textModules.last?["moduleTitle"] as? String) == "详细说明")
        #expect((modules.first { ($0["kind"] as? String) == "code" }?["moduleTitle"] as? String) == "代码示例")
        #expect((modules.first { ($0["kind"] as? String) == "link" }?["moduleTitle"] as? String) == "参考链接")
        #expect(modules.filter { ($0["kind"] as? String) == "image" }.allSatisfy { ($0["moduleTitle"] as? String) == "配图" })
    }

    @Test
    func importImageDataURISingleStringIsNotSplitByComma() {
        let dataURI = "data:image/png;base64,QUJDREVGRw=="
        let payload: [String: Any] = [
            "title": "Image URI",
            "images": dataURI
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let images = (normalized["images"] as? [String]) ?? []

        #expect(images.count == 1)
        #expect(images.first == dataURI)
    }

    @Test
    func importImageObjectEncodingCanBeNormalizedToDataURI() {
        let payload: [String: Any] = [
            "title": "Encoded Image",
            "images": [
                [
                    "encoding": "base64",
                    "mimeType": "image/png",
                    "data": "QUJDRA=="
                ]
            ]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let images = (normalized["images"] as? [String]) ?? []

        #expect(images.count == 1)
        #expect(images.first == "data:image/png;base64,QUJDRA==")
    }

    @Test
    func materializeImageSourcesConvertsDataURIToFileURL() throws {
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5nF1QAAAAASUVORK5CYII="
        let payload: [String: Any] = [
            "title": "Materialize",
            "images": [dataURI]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        let materialized = try ImportImageSourceResolver.materializeImageSources(in: normalized)

        let images = (materialized["images"] as? [String]) ?? []
        #expect(images.count == 1)
        #expect(images.first?.hasPrefix("file://") == true)

        let modules = (materialized["modules"] as? [[String: Any]]) ?? []
        let moduleImageURLs = (modules.first { ($0["kind"] as? String) == "image" }?["imageURLs"] as? [String]) ?? []
        #expect(moduleImageURLs.count == 1)
        #expect(moduleImageURLs.first?.hasPrefix("file://") == true)

        if let fileURLString = images.first, let fileURL = URL(string: fileURLString), fileURL.isFileURL {
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    @Test
    func materializeImageSourcesThrowsForInvalidBase64DataURI() {
        let payload: [String: Any] = [
            "title": "Invalid Image Data",
            "images": [
                "data:image/png;base64,###invalid###"
            ]
        ]

        let normalized = ImportPayloadNormalizer.normalizeCardPayload(payload)
        #expect(throws: ImportImageSourceResolverError.self) {
            try ImportImageSourceResolver.materializeImageSources(in: normalized)
        }
    }
}

struct KnowledgeSquareRecommendationTests {
    @Test
    func firstTextBodyPrefersTextModuleContent() {
        let card = KnowledgeCard(
            title: "标题",
            content: "Legacy Content",
            modules: [
                CardBlock(kind: .image, moduleTitle: "图片", imageURLs: ["https://example.com/a.png"]),
                CardBlock(kind: .text, moduleTitle: "正文", text: "  模块正文优先  "),
                CardBlock(kind: .text, moduleTitle: "补充", text: "次级正文")
            ]
        )

        let resolved = KnowledgeCardLViewContentResolver.firstTextBody(for: card)
        #expect(resolved == "模块正文优先")
    }

    @Test
    func firstTextBodyFallsBackToLegacyContent() {
        let card = KnowledgeCard(
            title: "标题",
            content: "  Legacy Fallback  ",
            modules: [
                CardBlock(kind: .text, moduleTitle: "正文", text: "   "),
                CardBlock(kind: .image, moduleTitle: "图片", imageURLs: ["https://example.com/a.png"])
            ]
        )

        let resolved = KnowledgeCardLViewContentResolver.firstTextBody(for: card)
        #expect(resolved == "Legacy Fallback")
    }

    @Test
    func punchedCardMetricsScaleAndMinimumFloor() {
        let scaled = ZDPunchedCardMetrics(cornerRadius: 18, holeScale: 1.02)
        #expect(abs(scaled.holeSize - (18 * 0.6875 * 1.02)) < 0.0001)
        #expect(abs(scaled.holeInset - (18 * 0.5833 * 1.02)) < 0.0001)

        let tiny = ZDPunchedCardMetrics(cornerRadius: 1, holeScale: 0.1)
        #expect(tiny.holeSize == 5.4)
        #expect(tiny.holeInset == 4.4)
    }
}

struct ListRenderModeTests {
    @Test
    func listRenderModeFallsBackToDefaultForUnknownValue() {
        #expect(ZDListRenderMode.resolve(rawValue: "unknown") == .defaultSelection)
        #expect(ZDListRenderMode.resolve(rawValue: "visual") == .visual)
        #expect(ZDListRenderMode.resolve(rawValue: "performance") == .performance)
    }

    @Test
    func listRenderProfilePerformanceIntensityIsMonotonic() {
        let visual = ZDListRenderMode.visual.profile
        let performance = ZDListRenderMode.performance.profile

        #expect(performance.materialStrength <= visual.materialStrength)
        #expect(performance.blurStrength <= visual.blurStrength)
        #expect(performance.primaryShadowStrength <= visual.primaryShadowStrength)
    }

    @Test
    func listRenderModeScopeSpecificBehaviorMatchesDesign() {
        let visualSquare = ZDListRenderMode.visual.profile(for: .knowledgeSquare)
        let visualWarehouse = ZDListRenderMode.visual.profile(for: .warehouse)
        let performanceSquare = ZDListRenderMode.performance.profile(for: .knowledgeSquare)
        let performanceWarehouse = ZDListRenderMode.performance.profile(for: .warehouse)

        #expect(visualSquare.glassQuality == .full)
        #expect(visualSquare.showsQuestionIcon)
        #expect(visualWarehouse.glassQuality == .full)
        #expect(visualWarehouse.showsQuestionIcon)

        #expect(performanceSquare.glassQuality == .off)
        #expect(performanceSquare.showsQuestionIcon)
        #expect(performanceSquare.questionPlacement == .bottomTrailing)
        #expect(performanceWarehouse.glassQuality == .off)
        #expect(performanceWarehouse.showsQuestionIcon)
        #expect(performanceWarehouse.questionPlacement == .bottomTrailing)
    }
}
