import SwiftUI
import UIKit

struct ImportCardView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var onCreate: ((KnowledgeCard) -> Void)?

    @State private var jsonText = ""
    @State private var importResult: ImportResult?
    @State private var isValidating = false
    @State private var promptCopied = false
    @State private var pasteApplied = false
    @State private var pendingImportPreviewCard: KnowledgeCard?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    infoSection
                        .padding(.top, 2)
                    promptGuideRow
                        .padding(.top, 18)
                    quickActionRow
                        .padding(.top, 10)
                    pasteSection
                        .padding(.top, 18)
                    resultSection
                        .padding(.top, 12)
                    importButton
                        .padding(.top, 16)
                }
                .padding(20)
            }
            .zdPageBackground()
            .navigationTitle("导入卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .font(.subheadline)
                }
            }
        }
        .sheet(item: $pendingImportPreviewCard) { card in
            ImportTagPreviewScreen(
                card: card,
                existingTags: library.allUniqueTags(),
                onConfirm: finalizeImport
            )
        }
    }

    private let assistIconTextSpacing: CGFloat = 12
    private let assistIconFrame: CGFloat = 24
    private let assistTextSpacing: CGFloat = 2
    private let assistRowMinHeight: CGFloat = 88

    private var assistTitleFont: Font { .subheadline.weight(.semibold) }
    private var assistSubtitleFont: Font { .caption }
    private var assistTitleColor: Color { .primary.opacity(0.88) }
    private var assistSubtitleColor: Color { .secondary }

    // MARK: - Info Section

    private var infoSection: some View {
        HStack(alignment: .top, spacing: assistIconTextSpacing) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.zdAccentDeep.opacity(0.82))
                .frame(width: assistIconFrame, height: assistIconFrame)

            VStack(alignment: .leading, spacing: assistTextSpacing) {
                Text("导入说明")
                    .font(assistTitleFont)
                    .foregroundStyle(assistTitleColor)
                Text("将知识卡片的 JSON 粘贴到下方输入框，即可快速导入。支持从外部 AI 整理后的标准格式。")
                    .font(assistSubtitleFont)
                    .foregroundStyle(assistSubtitleColor)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zdGlassSurface(cornerRadius: 14)
    }

    // MARK: - Prompt Guide Entry

    private var promptGuideRow: some View {
        NavigationLink {
            PromptGuideView(promptTemplate: promptTemplate)
        } label: {
            HStack(spacing: assistIconTextSpacing) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.zdAccentDeep.opacity(0.82))
                    .frame(width: assistIconFrame, height: assistIconFrame)

                VStack(alignment: .leading, spacing: assistTextSpacing) {
                    Text("获取 AI 整理 Prompt")
                        .font(assistTitleFont)
                        .foregroundStyle(assistTitleColor)
                    Text("点击查看完整 Prompt 与外部 AI 使用指引")
                        .font(assistSubtitleFont)
                        .foregroundStyle(assistSubtitleColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: assistRowMinHeight, alignment: .leading)
            .zdGlassSurface(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            quickActionCard(
                icon: promptCopied ? "checkmark.circle.fill" : "doc.on.doc.fill",
                title: "一键复制",
                subtitle: "复制到剪贴板",
                active: promptCopied,
                action: copyPromptTemplate
            )

            quickActionCard(
                icon: pasteApplied ? "checkmark.circle.fill" : "clipboard.fill",
                title: "一键粘贴",
                subtitle: "粘贴到输入框",
                active: pasteApplied,
                action: pasteClipboardContent
            )
        }
    }

    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: assistIconTextSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundStyle(active ? Color.zdAccentSoft : Color.zdAccentDeep.opacity(0.82))
                    .frame(width: assistIconFrame, height: assistIconFrame)

                VStack(alignment: .leading, spacing: assistTextSpacing) {
                    Text(title)
                        .font(assistTitleFont)
                        .foregroundStyle(assistTitleColor)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(assistSubtitleFont)
                        .foregroundStyle(assistSubtitleColor)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: assistRowMinHeight, alignment: .leading)
            .background(
                active
                    ? Color.zdAccentSoft.opacity(colorScheme == .dark ? 0.16 : 0.12)
                    : Color.clear
            )
            .zdGlassSurface(cornerRadius: 14, lineWidth: active ? 1.05 : 0.94)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Paste Section

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("粘贴 JSON")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !jsonText.isEmpty {
                    Button {
                        jsonText = ""
                        importResult = nil
                    } label: {
                        Text("清空")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.zdAccentDeep.opacity(0.78))
                    }
                }
            }

            RawTextEditor(text: $jsonText)
                .frame(minHeight: 180)
                .padding(12)
                .zdGlassSurface(cornerRadius: 14, isError: importResult?.isError == true)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        if let result = importResult {
            HStack(spacing: 8) {
                Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(result.isError ? Color.zdAccentDeep : Color.zdAccentSoft)
                Text(result.message)
                    .font(.subheadline)
                    .foregroundStyle(
                        result.isError
                            ? Color.zdAccentDeep.opacity(0.9)
                            : Color.zdAccentSoft.opacity(0.95)
                    )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((result.isError ? Color.zdAccentDeep : Color.zdAccentSoft).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Import Button

    private var importButton: some View {
        ZDPrimaryButton(
            text: isValidating ? "校验中..." : "导入卡片",
            icon: isValidating ? nil : "square.and.arrow.down",
            isDisabled: jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating
        ) {
            importCard()
        }
        .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
        .opacity(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }

    // MARK: - Import Logic

    private func copyPromptTemplate() {
        UIPasteboard.general.string = promptTemplate
        pasteApplied = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            promptCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                promptCopied = false
            }
        }
    }

    private func pasteClipboardContent() {
        guard let clipboard = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                importResult = ImportResult(isError: true, message: "剪贴板中没有可粘贴文本")
            }
            return
        }

        jsonText = clipboard
        importResult = nil
        promptCopied = false
        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            pasteApplied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                pasteApplied = false
            }
        }
    }

    private func importCard() {
        let rawInput = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty else { return }

        isValidating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let extracted = ImportPayloadNormalizer.extractJSONObject(from: rawInput)
                let decoded = ImportPayloadNormalizer.decodeJSONStringIfNeeded(extracted)
                let parsedDict = try ImportPayloadNormalizer.parseJSONObject(decoded)
                let normalizedDict = ImportPayloadNormalizer.normalizeCardPayload(parsedDict)
                let materializedDict = try ImportImageSourceResolver.materializeImageSources(in: normalizedDict)

                // 验证必填字段
                guard let title = materializedDict["title"] as? String,
                      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ImportError.missingField("title（标题）")
                }

                let rebuiltData = try JSONSerialization.data(withJSONObject: materializedDict)
                let card = try decoder.decode(KnowledgeCard.self, from: rebuiltData)
                importResult = nil
                pendingImportPreviewCard = card

            } catch ImportError.missingField(let field) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    importResult = ImportResult(isError: true, message: "缺少必填字段：\(field)")
                }
            } catch let error as ImportPayloadNormalizerError {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    importResult = ImportResult(isError: true, message: error.uiErrorMessage)
                }
            } catch let error as ImportImageSourceResolverError {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    importResult = ImportResult(isError: true, message: error.uiErrorMessage)
                }
            } catch let error as DecodingError {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    importResult = ImportResult(isError: true, message: decodingFailureMessage(error))
                }
            } catch {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    importResult = ImportResult(
                        isError: true,
                        message: "导入失败（错误码：IMP-UNKNOWN-001，原因：\(error.localizedDescription)）"
                    )
                }
            }

            isValidating = false
        }
    }

    private func finalizeImport(_ card: KnowledgeCard) {
        pendingImportPreviewCard = nil
        library.addCard(card)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            importResult = ImportResult(isError: false, message: "成功导入「\(card.title)」")
        }

        onCreate?(card)
    }

    private func decodingFailureMessage(_ error: DecodingError) -> String {
        let reason: String
        switch error {
        case .typeMismatch(let type, let context):
            reason = "字段 \(codingPathText(context.codingPath)) 类型不匹配（期望 \(type)）：\(context.debugDescription)"
        case .valueNotFound(let type, let context):
            reason = "字段 \(codingPathText(context.codingPath)) 缺失值（期望 \(type)）：\(context.debugDescription)"
        case .keyNotFound(let key, let context):
            reason = "缺少键 \(key.stringValue)（路径 \(codingPathText(context.codingPath))）"
        case .dataCorrupted(let context):
            reason = "数据损坏（路径 \(codingPathText(context.codingPath))）：\(context.debugDescription)"
        @unknown default:
            reason = "未知解码错误"
        }
        return "卡片数据映射失败（错误码：IMP-DECODE-001，原因：\(reason)）"
    }

    private func codingPathText(_ codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        return codingPath.map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }
            return key.stringValue
        }
        .joined(separator: ".")
    }

    // MARK: - Data

    private var promptTemplate: String {
        """
        你是“专家级知识卡片构建师”。请根据我们刚刚讨论的知识内容，为我深度总结并生成用于导入的标准化 JSON 数据。

        【输出格式约束】（必须严格遵守）
        1. 只允许输出一个 ```json 代码块```，代码块外部绝对不要有任何多余的解释文字、问候或分析。
        2. 暂时不输出 `tags` 字段（留作人工填写）。
        3. 必须包含固定字段：`title`、`content`、`links`、`codeSnippets`、`images`、`moduleLayout`、`moduleTitles`。
        4. `content` 必须是长度为 2 的字符串数组，用于两个文字内容块：
           - `content[0]`：必须是“三级标题 ### + 一段直接回答标题的问题”
             格式示例：`### 直接结论\n这里是一段直接回答标题的问题`
           - `content[1]`：必须是普通正文格式，对问题做详细描述（不要再加 `#` 或 `##` 标题）
        5. `moduleTitles` 必须固定输出并包含每个内容块名称：
           - `"text": ["一句话总结", "详细说明"]`
           - `"code": "代码示例"`
           - `"link": "参考链接"`
           - `"image": "相关图片"`
        6. `moduleLayout` 必须固定输出：
           - `"text": "split"`（让上述两段文字进入两个文字块）
           - `"code": "group"`（让多段代码进入同一个代码块）
           - `"link": "group"`（让多个链接进入同一个链接块）
           - `"image": "split"`（图片按默认分块）
        7. 当 `links` / `codeSnippets` / `images` 没有可用数据时，必须输出空数组 `[]`。
        8. `images` 必须是数组；如有图片，优先输出 `data:image/<mime>;base64,<payload>` 格式，严禁编造图片 URL。
        9. JSON 必须是严格标准格式（英文双引号、无注释、无尾逗号、正确转义）。

        【内容约束】
        - title：必须是一句简洁问句，优先使用“为什么...？”或“...是什么？”。
        - content[0]：必须以 `###` 开头，并直接回答标题问题。
        - content[1]：详细解释底层原理、应用场景、常见误区，结构清晰但不过度分层。
        - codeSnippets：可输出多段代码；多段代码会被放入同一个代码块，请保证每段 `name`、`language`、`code` 完整。
        - images：如能提供图片，请优先输出 `data:image/<mime>;base64,<payload>` 编码；无法提供时输出 `[]`。
        - links：可输出多个链接，都会归属同一个链接块。必须优先检索视频教程来源：
          1. Bilibili
          2. 小红书
          3. 抖音
          若以上平台存在相关高质量教程，优先输出这些链接；并可补充少量官方文档/高质量文章。严禁编造链接。

        【输出示例参考】
        ```json
        {
          "title": "Undercut 战术是什么？为什么它能不超车却完成反超？",
          "content": [
            "### 直接结论\nUndercut 通过提前换新胎创造圈速窗口，在时间维度完成反超。",
            "Undercut 是后车提前进站换新胎，通过出站后数圈的速度窗口累计净时间收益，等待前车进站后实现位置反转。其成立依赖轮胎性能衰减曲线、进站总损失、出站后交通状况与圈速差。若出站遭遇慢车、或对手立即跟进进站（cover undercut），收益会被迅速抹平。"
          ],
          "moduleTitles": {
            "text": ["一句话总结", "详细说明"],
            "code": "代码示例",
            "link": "参考链接",
            "image": "相关图片"
          },
          "moduleLayout": {
            "text": "split",
            "code": "group",
            "link": "group",
            "image": "split"
          },
          "links": [
            {
              "url": "https://www.bilibili.com/video/example_a",
              "title": "Bilibili：F1 Undercut 战术解析"
            },
            {
              "url": "https://www.xiaohongshu.com/explore/example_b",
              "title": "小红书：Undercut 与 Overcut 实战对比"
            }
          ],
          "codeSnippets": [
            {
              "name": "Undercut 时间收益估算",
              "language": "python",
              "code": "def undercut_gain(delta_per_lap, laps, pit_loss, initial_gap):\n    return delta_per_lap * laps - pit_loss - initial_gap"
            },
            {
              "name": "战术成立条件",
              "language": "bash",
              "code": "echo \"(新胎圈速优势 * 圈数) > 进站损失 + 初始差距\""
            }
          ],
          "images": [
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
          ]
        }
        """
    }
}

// MARK: - Helper Types

private enum ImportError: Error {
    case missingField(String)
}

private struct ImportResult {
    let isError: Bool
    let message: String
}

private struct PromptGuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    let promptTemplate: String
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                usageGuide
                promptCard
                copyButton
            }
            .padding(20)
        }
        .zdPageBackground()
        .navigationTitle("Prompt 使用指引")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var usageGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("如何使用")
                .font(.headline.weight(.semibold))

            Text("1. 复制下方 Prompt。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("2. 在外部 AI 里先正常提问，拿到一段初步回答。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("3. 把 Prompt 发给外部 AI，再贴入那段回答，请它只返回一个 JSON 代码块。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("4. 图片支持 data:image/...;base64 编码，直接放在 images 数组即可。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("5. 把返回的 JSON 粘贴回「导入卡片」页。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zdGlassSurface(cornerRadius: 14)
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt 内容")
                .font(.headline.weight(.semibold))

            Text(promptTemplate)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(12)
                .zdGlassSurface(cornerRadius: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zdGlassSurface(cornerRadius: 14)
    }

    private var copyButton: some View {
        return ZDPrimaryButton(
            text: copied ? "已复制 Prompt" : "复制 Prompt",
            icon: copied ? "checkmark.circle.fill" : "doc.on.doc",
            fullWidth: true
        ) {
            UIPasteboard.general.string = promptTemplate
            withAnimation(.easeInOut(duration: 0.18)) {
                copied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    copied = false
                }
            }
        }
        .background {
            if copied {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.zdAccentSoft.opacity(0.22))
            }
        }
    }
}

struct ImportTagPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let card: KnowledgeCard
    let existingTags: [String]
    let onConfirm: (KnowledgeCard) -> Void

    @State private var tagInput = ""
    @State private var selectedTags: [String]

    init(
        card: KnowledgeCard,
        existingTags: [String],
        onConfirm: @escaping (KnowledgeCard) -> Void
    ) {
        self.card = card
        self.existingTags = existingTags
        self.onConfirm = onConfirm
        _selectedTags = State(initialValue: Self.sanitizedTags(from: card.tags ?? []))
    }

    private var theme: CardThemeColor {
        card.themeColor ?? .defaultTheme
    }

    private var useLightPreviewText: Bool {
        theme.prefersLightForeground(in: colorScheme)
    }

    private var selectedTagKeys: Set<String> {
        Set(selectedTags.map { $0.lowercased() })
    }

    private var availableExistingTags: [String] {
        existingTags.filter { tag in
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                return false
            }
            return !selectedTagKeys.contains(normalized.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    previewCard
                    tagEditorSection
                    existingTagSection
                }
                .padding(20)
            }
            .zdPageBackground()
            .navigationTitle("添加标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.subheadline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        confirmImport()
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.title)
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(useLightPreviewText ? Color.white.opacity(0.95) : .primary)
                .lineLimit(3)

            HStack(alignment: .center, spacing: 8) {
                Group {
                    if selectedTags.isEmpty {
                        Text("点击下方输入或从已有标签中添加")
                            .font(.caption)
                            .foregroundStyle(useLightPreviewText ? Color.white.opacity(0.82) : .secondary)
                    } else {
                        selectedTagRow
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(card.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(useLightPreviewText ? Color.white.opacity(0.82) : .secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TitleCardPunchedShape(cornerRadius: 24, holeSize: 16.5, holeInset: 14)
                .fill(theme.cardBackgroundGradient, style: FillStyle(eoFill: true))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            TitleCardPunchedShape(cornerRadius: 24, holeSize: 16.5, holeInset: 14)
                .stroke(theme.cardBorderGradient.opacity(0.58), lineWidth: 0.78)
        )
        .overlay(
            TitleCardPunchedShape(cornerRadius: 24, holeSize: 16.5, holeInset: 14)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.white.opacity(0.2),
                    lineWidth: 0.4
                )
                .padding(1)
        )
        .overlay(alignment: .topTrailing) {
            KnowledgeCardPinHoleInnerShadow(size: 16.5)
                .padding(.top, 14)
                .padding(.trailing, 14)
                .allowsHitTesting(false)
        }
    }

    private var tagEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("添加标签")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("输入标签（支持逗号分隔）", text: $tagInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.zdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit(addInputTags)

                Button("添加") {
                    addInputTags()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.zdAccentSoft.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("已添加标签会展示在上方标题卡片中，可直接点击标签右上角的 x 删除。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .zdGlassSurface(cornerRadius: 14, lineWidth: 0.9)
    }

    private var existingTagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已有标签")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("点选可快速添加")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if availableExistingTags.isEmpty {
                Text("暂无已有标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                tagWrap(tags: availableExistingTags)
            }
        }
        .padding(14)
        .zdGlassSurface(cornerRadius: 14, lineWidth: 0.9)
    }

    private var selectedTagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(selectedTags, id: \.self) { tag in
                    Text("# \(tag)")
                        .lineLimit(1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            useLightPreviewText
                                ? Color.white.opacity(0.9)
                                : Color.zdAccentDeep.opacity(0.9)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(useLightPreviewText ? 0.18 : 0.34))
                        .clipShape(Capsule())
                        .overlay(alignment: .topTrailing) {
                            Button {
                                removeTag(tag)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 14, height: 14)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 5, y: -5)
                        }
                }
            }
            .padding(.top, 5)
            .padding(.trailing, 5)
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
    }

    @ViewBuilder
    private func tagWrap(tags: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 84), alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    addTags([tag])
                } label: {
                    HStack(spacing: 5) {
                        Text(tag)
                            .lineLimit(1)
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        useLightPreviewText
                            ? Color.white.opacity(0.88)
                            : theme.primaryColor.opacity(0.88)
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        useLightPreviewText
                            ? Color.white.opacity(0.12)
                            : Color.zdAccentSoft.opacity(0.16)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addInputTags() {
        let pieces = tagInput
            .components(separatedBy: CharacterSet(charactersIn: ",，\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        addTags(pieces)
        tagInput = ""
    }

    private func addTags(_ tags: [String]) {
        guard !tags.isEmpty else {
            return
        }
        selectedTags = Self.sanitizedTags(from: selectedTags + tags)
    }

    private func removeTag(_ tag: String) {
        selectedTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private func confirmImport() {
        var finalized = card
        let tags = Self.sanitizedTags(from: selectedTags)
        finalized.tags = tags.isEmpty ? nil : tags
        finalized.touchUpdatedAt()
        onConfirm(finalized)
        dismiss()
    }

    private static func sanitizedTags(from tags: [String], maxCount: Int = 24) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in tags {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                continue
            }
            let key = value.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(value)
            if result.count >= maxCount {
                break
            }
        }
        return result
    }
}

#Preview("Import Card") {
    ImportCardView()
        .environmentObject(KnowledgeCardLibraryStore())
}

// MARK: - Raw Text Editor (disables smart quotes)

private struct RawTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.spellCheckingType = .no
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}
