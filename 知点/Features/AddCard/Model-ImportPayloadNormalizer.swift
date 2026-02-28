import Foundation

enum ImportPayloadNormalizerError: Error {
    case invalidJSON(code: String, reason: String)
    case notJSONObject(code: String, reason: String)

    var code: String {
        switch self {
        case .invalidJSON(let code, _):
            return code
        case .notJSONObject(let code, _):
            return code
        }
    }

    var reason: String {
        switch self {
        case .invalidJSON(_, let reason):
            return reason
        case .notJSONObject(_, let reason):
            return reason
        }
    }

    var titleMessage: String {
        switch self {
        case .invalidJSON:
            return "无法解析为有效的 JSON 对象"
        case .notJSONObject:
            return "解析结果不是 JSON 对象"
        }
    }

    var uiErrorMessage: String {
        "\(titleMessage)（错误码：\(code)，原因：\(reason)）"
    }
}

enum ImportPayloadNormalizer {
    nonisolated static func extractJSONObject(from raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```json") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```JSON") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = text.firstIndex(of: "{"),
           let last = text.lastIndex(of: "}"),
           first <= last {
            return String(text[first...last]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
    }

    nonisolated static func decodeJSONStringIfNeeded(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return trimmed
        }

        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let stringObject = object as? String else {
            return trimmed
        }

        return stringObject.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func parseJSONObject(_ text: String) throws -> [String: Any] {
        let base = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            throw ImportPayloadNormalizerError.invalidJSON(
                code: "IMP-JSON-001",
                reason: "输入内容为空"
            )
        }

        var attempts = buildParseAttempts(for: base, prefix: "raw")

        let decodedRaw = decodeJSONStringIfNeeded(base)
        if decodedRaw != base {
            attempts.append(contentsOf: buildParseAttempts(for: decodedRaw, prefix: "decoded_stringified"))
        }

        var seen = Set<String>()
        var lastParseReason = "未知原因"

        for attempt in attempts {
            let candidate = attempt.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty, !seen.contains(candidate) else {
                continue
            }
            seen.insert(candidate)

            do {
                let object = try parseJSONRoot(from: candidate)
                guard let dict = object as? [String: Any] else {
                    throw ImportPayloadNormalizerError.notJSONObject(
                        code: "IMP-JSON-002",
                        reason: "根节点不是 JSON 对象（当前为 \(jsonRootTypeName(of: object))）"
                    )
                }
                return dict
            } catch let error as ImportPayloadNormalizerError {
                if case .notJSONObject = error {
                    throw error
                }
                lastParseReason = "\(attempt.name): \(error.reason)"
            } catch {
                lastParseReason = "\(attempt.name): \(error.localizedDescription)"
            }
        }

        throw ImportPayloadNormalizerError.invalidJSON(
            code: "IMP-JSON-003",
            reason: lastParseReason
        )
    }

    nonisolated static func normalizeCardPayload(_ dict: [String: Any]) -> [String: Any] {
        var mutable = dict

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = formatter.string(from: Date())

        mutable["id"] = (dict["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? dict["id"]
            : UUID().uuidString
        mutable["createdAt"] = (dict["createdAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? dict["createdAt"]
            : now
        mutable["updatedAt"] = (dict["updatedAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? dict["updatedAt"]
            : now

        // Legacy field retained for backward compatibility; unified flow always uses one style.
        mutable["type"] = "short"

        let title = (dict["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        mutable["title"] = title

        let normalizedTextSegments = normalizeTopLevelTextSegments(from: dict)
        let normalizedContent = joinTextSegments(normalizedTextSegments)
        mutable["content"] = normalizedContent

        mutable["tags"] = normalizeStringArray(dict["tags"])

        let normalizedImages = normalizeImageSourceArray(dict["images"])
        if normalizedImages.isEmpty {
            mutable.removeValue(forKey: "images")
        } else {
            mutable["images"] = normalizedImages
        }

        let normalizedLinks = normalizeLinks(dict["links"])
        if normalizedLinks.isEmpty {
            mutable.removeValue(forKey: "links")
        } else {
            mutable["links"] = normalizedLinks
        }

        let normalizedCodeSnippets = normalizeCodeSnippets(dict["codeSnippets"])
        mutable["codeSnippets"] = normalizedCodeSnippets

        let moduleLayout = normalizeModuleLayout(
            dict["moduleLayout"] ?? dict["importLayout"] ?? dict["moduleMode"]
        )
        let moduleTitles = normalizeModuleTitles(from: dict)

        let normalizedModules = normalizeModules(
            from: dict,
            normalizedTextSegments: normalizedTextSegments,
            normalizedImages: normalizedImages,
            normalizedCodeSnippets: normalizedCodeSnippets,
            normalizedLinks: normalizedLinks,
            layout: moduleLayout,
            titles: moduleTitles
        )
        mutable["modules"] = normalizedModules
        mutable["blocks"] = normalizedModules
        mutable["themeColor"] = CardThemeColor.defaultTheme.rawValue

        return mutable
    }

    nonisolated static func normalizeMarkdownContent(_ content: String) -> String {
        var text = normalizeLineEndings(content)
        text = decodeHTMLEntities(text)
        text = decodeEscapedControlSequencesDeterministically(text)
        text = normalizeLineEndings(text)
        text = wrapLanguageTaggedXMLBlocks(text)
        text = escapeUnfencedXMLLines(text)
        text = collapseExtraBlankLines(text, maxConsecutiveBlankLines: 1)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func decodeEscapedControlSequencesDeterministically(
        _ text: String,
        maxPasses: Int = 2
    ) -> String {
        guard maxPasses > 0 else { return text }

        var output = normalizeLineEndings(text)
        var pass = 0

        while pass < maxPasses {
            pass += 1
            let next = output
                // Handle double-escaped control sequences first.
                .replacingOccurrences(of: "\\\\r\\\\n", with: "\n")
                .replacingOccurrences(of: "\\\\n", with: "\n")
                .replacingOccurrences(of: "\\\\r", with: "\n")
                .replacingOccurrences(of: "\\\\t", with: "\t")
                // Then handle regular escaped control sequences.
                .replacingOccurrences(of: "\\r\\n", with: "\n")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")

            let normalized = normalizeLineEndings(next)
            if normalized == output {
                break
            }
            output = normalized
        }

        return output
    }
}

private extension ImportPayloadNormalizer {
    nonisolated static func parseJSONRoot(from text: String) throws -> Any {
        guard let data = text.data(using: .utf8) else {
            throw ImportPayloadNormalizerError.invalidJSON(
                code: "IMP-JSON-004",
                reason: "无法转换为 UTF-8 数据"
            )
        }

        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            let nsError = error as NSError
            let idx = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int
            let idxText = idx.map { "，位置索引：\($0)" } ?? ""
            let contextText = idx.flatMap { jsonContextSnippet(in: text, aroundUTF16Index: $0) }
                .map { "，附近内容：\($0)" } ?? ""
            throw ImportPayloadNormalizerError.invalidJSON(
                code: "IMP-JSON-005",
                reason: "\(nsError.localizedDescription)\(idxText)\(contextText)"
            )
        }
    }

    nonisolated static func jsonRootTypeName(of object: Any) -> String {
        if object is [Any] { return "数组" }
        if object is String { return "字符串" }
        if object is NSNumber { return "数字/布尔" }
        if object is NSNull { return "null" }
        return "其他"
    }

    nonisolated static func canonicalizeQuoteDelimiters(in text: String) -> String {
        let chars = Array(text)
        var out = ""
        var inString = false
        var isEscaping = false
        var index = 0

        while index < chars.count {
            let c = chars[index]

            if inString {
                if isEscaping {
                    out.append(c)
                    isEscaping = false
                    index += 1
                    continue
                }

                if c == "\\" {
                    out.append(c)
                    isEscaping = true
                    index += 1
                    continue
                }

                if isQuoteChar(c) {
                    if shouldCloseJSONString(at: index, chars: chars) {
                        out.append("\"")
                        inString = false
                    } else {
                        out.append("\\\"")
                    }
                    index += 1
                    continue
                }

                out.append(c)
                index += 1
                continue
            }

            if isQuoteChar(c) {
                inString = true
                out.append("\"")
            } else {
                out.append(c)
            }
            index += 1
        }

        return out
    }

    nonisolated static func buildParseAttempts(for text: String, prefix: String) -> [(name: String, content: String)] {
        let punctuationNormalized = normalizeJSONPunctuation(in: text)
        let canonicalized = canonicalizeQuoteDelimiters(in: text)
        let punctuationThenCanonicalized = canonicalizeQuoteDelimiters(in: punctuationNormalized)
        let canonicalizedPunctuationNormalized = normalizeJSONPunctuation(in: canonicalized)
        let punctuationThenReplaced = replaceSmartQuotes(in: punctuationNormalized)

        return [
            ("\(prefix)", text),
            ("\(prefix)_punctuation_normalized", punctuationNormalized),
            ("\(prefix)_punctuation_then_canonicalized", punctuationThenCanonicalized),
            ("\(prefix)_smart_quote_canonicalized", canonicalized),
            ("\(prefix)_canonicalized_punctuation_normalized", canonicalizedPunctuationNormalized),
            ("\(prefix)_punctuation_then_replaced", punctuationThenReplaced),
            ("\(prefix)_smart_quote_replaced", replaceSmartQuotes(in: text))
        ]
    }

    nonisolated static func isQuoteChar(_ c: Character) -> Bool {
        c == "\"" || c == "\u{201C}" || c == "\u{201D}"
    }

    nonisolated static func shouldCloseJSONString(at index: Int, chars: [Character]) -> Bool {
        var probe = index + 1
        while probe < chars.count {
            let c = chars[probe]
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                probe += 1
                continue
            }
            return c == ":" || c == "," || c == "}" || c == "]"
        }
        return true
    }

    nonisolated static func normalizeJSONPunctuation(in text: String) -> String {
        let chars = Array(text)
        var out = ""
        var inString = false
        var isEscaping = false

        for c in chars {
            if inString {
                if isEscaping {
                    out.append(c)
                    isEscaping = false
                    continue
                }

                if c == "\\" {
                    out.append(c)
                    isEscaping = true
                    continue
                }

                if isQuoteChar(c) {
                    inString = false
                }

                out.append(c)
                continue
            }

            if isQuoteChar(c) {
                inString = true
                out.append(c)
                continue
            }

            switch c {
            case "\u{00A0}", "\u{202F}", "\u{3000}":
                out.append(" ")
            case "：":
                out.append(":")
            case "，", "、":
                out.append(",")
            case "；":
                out.append(";")
            case "｛":
                out.append("{")
            case "｝":
                out.append("}")
            case "［":
                out.append("[")
            case "］":
                out.append("]")
            default:
                out.append(c)
            }
        }

        return out
    }

    nonisolated static func normalizeLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    nonisolated static func replaceSmartQuotes(in text: String) -> String {
        text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
    }

    nonisolated static func jsonContextSnippet(in text: String, aroundUTF16Index index: Int, radius: Int = 20) -> String? {
        let source = text as NSString
        guard source.length > 0 else { return nil }

        let boundedIndex = max(0, min(index, source.length - 1))
        let start = max(0, boundedIndex - radius)
        let length = min(source.length - start, radius * 2)
        guard length > 0 else { return nil }

        let snippet = source.substring(with: NSRange(location: start, length: length))
        let escaped = snippet
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return escaped.isEmpty ? nil : "…\(escaped)…"
    }

    nonisolated static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    nonisolated static func normalizeImageSourceArray(_ value: Any?) -> [String] {
        if let single = value as? String {
            let normalized = decodeHTMLEntities(single).trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? [] : [normalized]
        }

        if let array = value as? [String] {
            return array
                .map { decodeHTMLEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let list = value as? [Any] {
            var result: [String] = []
            result.reserveCapacity(list.count)

            for item in list {
                if let source = item as? String {
                    let normalized = decodeHTMLEntities(source).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalized.isEmpty {
                        result.append(normalized)
                    }
                    continue
                }

                if let object = item as? [String: Any],
                   let encoded = normalizeEncodedImageObject(object) {
                    result.append(encoded)
                }
            }

            return result
        }

        if let object = value as? [String: Any],
           let encoded = normalizeEncodedImageObject(object) {
            return [encoded]
        }

        return []
    }

    nonisolated static func normalizeEncodedImageObject(_ object: [String: Any]) -> String? {
        let rawData = (
            object["data"] as? String ??
                object["base64"] as? String ??
                object["payload"] as? String ??
                ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawData.isEmpty else {
            return nil
        }

        if rawData.lowercased().hasPrefix("data:image/") {
            return rawData
        }

        let encoding = (object["encoding"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let mimeType = normalizedMimeTypeForEncodedImage(
            object["mimeType"] as? String ??
                object["mime"] as? String ??
                "image/jpeg"
        )

        if encoding.isEmpty || encoding == "base64" || encoding == "b64" {
            return "data:\(mimeType);base64,\(rawData)"
        }

        if encoding == "data_uri" || encoding == "dataurl" || encoding == "uri" {
            if rawData.lowercased().hasPrefix("data:") {
                return rawData
            }
            return "data:\(mimeType);base64,\(rawData)"
        }

        return nil
    }

    nonisolated static func normalizedMimeTypeForEncodedImage(_ raw: String) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.isEmpty {
            return "image/jpeg"
        }

        if normalized.hasPrefix("image/") {
            return normalized
        }

        return "image/\(normalized)"
    }

    nonisolated static func normalizeStringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
                .map { decodeHTMLEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let single = value as? String {
            return single
                .split(separator: ",")
                .map { decodeHTMLEntities(String($0)).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    nonisolated static func normalizeLinks(_ value: Any?) -> [[String: Any]] {
        guard let rawLinks = value as? [[String: Any]] else { return [] }

        return rawLinks.compactMap { item in
            let rawURL = (item["url"] as? String) ?? ""
            let rawTitle = (item["title"] as? String) ?? ""

            let markdownParts = parseMarkdownLink(rawURL)
            let resolvedURL = cleanLinkURL(markdownParts?.url ?? rawURL)
            guard !resolvedURL.isEmpty else { return nil }

            let defaultTitle = markdownParts?.title ?? "参考链接"
            let resolvedTitle = decodeHTMLEntities(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = resolvedTitle.isEmpty ? defaultTitle : resolvedTitle

            return [
                "id": (item["id"] as? String) ?? UUID().uuidString,
                "url": resolvedURL,
                "title": title
            ]
        }
    }

    nonisolated static func parseMarkdownLink(_ raw: String) -> (title: String, url: String)? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("["),
              let closeBracket = text.firstIndex(of: "]"),
              let openParen = text.firstIndex(of: "("),
              let closeParen = text.lastIndex(of: ")"),
              closeBracket < openParen,
              openParen < closeParen else {
            return nil
        }

        let title = String(text[text.index(after: text.startIndex)..<closeBracket])
        let url = String(text[text.index(after: openParen)..<closeParen])
        return (title, url)
    }

    nonisolated static func cleanLinkURL(_ raw: String) -> String {
        var text = decodeHTMLEntities(raw)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("www.") {
            text = "https://" + text
        }

        let lowercased = text.lowercased()
        guard lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") else {
            return ""
        }

        return text
    }

    nonisolated static func normalizeCodeSnippets(_ value: Any?) -> [[String: Any]] {
        guard let rawSnippets = value as? [[String: Any]] else { return [] }

        return rawSnippets.compactMap { item in
            let rawCode = item["code"] as? String ?? ""
            var code = normalizeLineEndings(rawCode)
            code = decodeHTMLEntities(code)
            code = decodeEscapedControlSequencesDeterministically(code)

            guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

            let name = decodeHTMLEntities(item["name"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let language = decodeHTMLEntities(item["language"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return [
                "id": (item["id"] as? String) ?? UUID().uuidString,
                "name": name.isEmpty ? "未命名代码块" : name,
                "language": language.isEmpty ? "text" : language,
                "code": code
            ]
        }
    }

    enum ModuleDistributionMode {
        case grouped
        case split
    }

    typealias ModuleLayoutSpec = (
        text: ModuleDistributionMode,
        image: ModuleDistributionMode,
        code: ModuleDistributionMode,
        link: ModuleDistributionMode
    )

    typealias ModuleTitleSpec = (
        text: [String],
        image: String,
        code: String,
        link: String
    )

    nonisolated static func defaultModuleLayoutSpec() -> ModuleLayoutSpec {
        (
            text: .grouped,
            image: .split,
            code: .split,
            link: .split
        )
    }

    nonisolated static func defaultModuleTitleSpec() -> ModuleTitleSpec {
        (
            text: ["文本"],
            image: "图片",
            code: "代码",
            link: "链接"
        )
    }

    nonisolated static func normalizeTopLevelTextSegments(from dict: [String: Any]) -> [String] {
        let source = dict["textBlocks"] ?? dict["texts"] ?? dict["content"]
        return normalizeTextSegments(source)
    }

    nonisolated static func normalizeTextSegments(_ value: Any?) -> [String] {
        if let text = value as? String {
            let normalized = normalizeMarkdownContent(text)
            return normalized.isEmpty ? [] : [normalized]
        }

        if let segments = value as? [String] {
            return segments
                .map(normalizeMarkdownContent)
                .filter { !$0.isEmpty }
        }

        if let segments = value as? [Any] {
            return segments.compactMap { item in
                if let text = item as? String {
                    let normalized = normalizeMarkdownContent(text)
                    return normalized.isEmpty ? nil : normalized
                }

                if let dict = item as? [String: Any],
                   let text = (dict["text"] as? String) ?? (dict["content"] as? String) {
                    let normalized = normalizeMarkdownContent(text)
                    return normalized.isEmpty ? nil : normalized
                }

                return nil
            }
        }

        return []
    }

    nonisolated static func joinTextSegments(_ segments: [String]) -> String {
        segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func normalizeOptionalString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let stringValue = value as? String {
            let normalized = decodeHTMLEntities(stringValue).trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }
        return nil
    }

    nonisolated static func normalizeModuleTitles(from dict: [String: Any]) -> ModuleTitleSpec {
        var titles = defaultModuleTitleSpec()
        let source = dict["moduleTitles"] as? [String: Any]

        let textCandidates = normalizeStringArray(
            source?["text"] ??
                source?["texts"] ??
                dict["textModuleTitles"] ??
                dict["textBlockTitles"]
        )
        if !textCandidates.isEmpty {
            titles.text = textCandidates
        } else if let singleText = normalizeOptionalString(
            source?["text"] ??
                dict["textModuleTitle"] ??
                dict["textBlockTitle"]
        ) {
            titles.text = [singleText]
        }

        if let imageTitle = normalizeOptionalString(
            source?["image"] ??
                dict["imageModuleTitle"] ??
                dict["imageBlockTitle"]
        ) {
            titles.image = imageTitle
        }
        if let codeTitle = normalizeOptionalString(
            source?["code"] ??
                dict["codeModuleTitle"] ??
                dict["codeBlockTitle"]
        ) {
            titles.code = codeTitle
        }
        if let linkTitle = normalizeOptionalString(
            source?["link"] ??
                dict["linkModuleTitle"] ??
                dict["linkBlockTitle"]
        ) {
            titles.link = linkTitle
        }
        return titles
    }

    nonisolated static func resolveModuleTitle(
        from raw: [String: Any],
        defaultTitle: String
    ) -> String {
        let candidates: [Any?] = [
            raw["moduleTitle"],
            raw["moduleName"],
            raw["blockTitle"],
            raw["blockName"],
            raw["sectionTitle"],
            raw["title"]
        ]
        for value in candidates {
            if let resolved = normalizeOptionalString(value) {
                return resolved
            }
        }
        return defaultTitle
    }

    nonisolated static func textModuleTitle(
        at index: Int,
        titles: [String],
        defaultTitle: String
    ) -> String {
        if index >= 0, index < titles.count {
            return titles[index]
        }
        return titles.first ?? defaultTitle
    }

    nonisolated static func normalizeModuleLayout(_ value: Any?) -> ModuleLayoutSpec {
        var layout = defaultModuleLayoutSpec()
        guard let value else {
            return layout
        }

        if let mode = moduleDistributionMode(from: value, defaultMode: nil) {
            layout.text = mode
            layout.image = mode
            layout.code = mode
            layout.link = mode
            return layout
        }

        guard let dict = value as? [String: Any] else {
            return layout
        }

        if let mode = moduleDistributionMode(from: dict["text"], defaultMode: nil) {
            layout.text = mode
        }
        if let mode = moduleDistributionMode(from: dict["image"], defaultMode: nil) {
            layout.image = mode
        }
        if let mode = moduleDistributionMode(from: dict["code"], defaultMode: nil) {
            layout.code = mode
        }
        if let mode = moduleDistributionMode(from: dict["link"], defaultMode: nil) {
            layout.link = mode
        }
        return layout
    }

    nonisolated static func moduleDistributionMode(
        from value: Any?,
        defaultMode: ModuleDistributionMode
    ) -> ModuleDistributionMode {
        guard let mode = moduleDistributionMode(from: value, defaultMode: nil) else {
            return defaultMode
        }
        return mode
    }

    nonisolated static func moduleDistributionMode(
        from value: Any?,
        defaultMode: ModuleDistributionMode?
    ) -> ModuleDistributionMode? {
        guard let value else {
            return defaultMode
        }

        if let boolValue = value as? Bool {
            return boolValue ? .split : .grouped
        }

        guard let rawString = value as? String else {
            return defaultMode
        }

        let normalized = rawString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        let groupedTokens: Set<String> = [
            "group", "grouped", "single", "one", "merged", "merge",
            "same_block", "same", "同块", "同一块", "单块", "合并"
        ]
        if groupedTokens.contains(normalized) {
            return .grouped
        }

        let splitTokens: Set<String> = [
            "split", "separate", "multiple", "many", "multi", "per_item",
            "split_blocks", "分块", "多块", "拆分", "分别"
        ]
        if splitTokens.contains(normalized) {
            return .split
        }

        return defaultMode
    }

    nonisolated static func normalizeCodeSnippetsFromModule(_ raw: [String: Any]) -> [[String: Any]] {
        var snippets = normalizeCodeSnippets(raw["snippets"] ?? raw["codeSnippets"])
        if !snippets.isEmpty {
            return snippets
        }

        if let snippet = raw["codeSnippet"] as? [String: Any] {
            snippets = normalizeCodeSnippets([snippet])
            if !snippets.isEmpty {
                return snippets
            }
        }

        if let code = raw["code"] as? String {
            snippets = normalizeCodeSnippets([[
                "name": (raw["name"] as? String) ?? "未命名代码块",
                "language": (raw["language"] as? String) ?? "text",
                "code": code
            ]])
        }
        return snippets
    }

    nonisolated static func normalizeLinksFromModule(_ raw: [String: Any]) -> [[String: Any]] {
        if let links = raw["linkItems"] as? [[String: Any]], !links.isEmpty {
            return normalizeLinks(links)
        }

        if let links = raw["links"] as? [[String: Any]], !links.isEmpty {
            return normalizeLinks(links)
        }

        if let link = raw["linkItem"] as? [String: Any] {
            return normalizeLinks([link])
        }

        return normalizeLinks([raw])
    }

    nonisolated static func normalizeModules(
        from dict: [String: Any],
        normalizedTextSegments: [String],
        normalizedImages: [String],
        normalizedCodeSnippets: [[String: Any]],
        normalizedLinks: [[String: Any]],
        layout: ModuleLayoutSpec,
        titles: ModuleTitleSpec
    ) -> [[String: Any]] {
        if let explicitModules = dict["modules"] as? [[String: Any]] {
            let normalized = explicitModules.flatMap {
                normalizeModuleBlocks($0, defaultLayout: layout, defaultTitles: titles)
            }
            if !normalized.isEmpty {
                return normalized
            }
        }

        if let legacyBlocks = dict["blocks"] as? [[String: Any]] {
            let normalized = legacyBlocks.flatMap {
                normalizeModuleBlocks($0, defaultLayout: layout, defaultTitles: titles)
            }
            if !normalized.isEmpty {
                return normalized
            }
        }

        var fallback: [[String: Any]] = []

        if !normalizedTextSegments.isEmpty {
            switch layout.text {
            case .grouped:
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "text",
                    "moduleTitle": textModuleTitle(at: 0, titles: titles.text, defaultTitle: "文本"),
                    "text": joinTextSegments(normalizedTextSegments)
                ])
            case .split:
                fallback.append(contentsOf: normalizedTextSegments.enumerated().map { index, text in
                    [
                        "id": UUID().uuidString,
                        "kind": "text",
                        "moduleTitle": textModuleTitle(at: index, titles: titles.text, defaultTitle: "文本"),
                        "text": text
                    ]
                })
            }
        }

        switch layout.image {
        case .grouped:
            if let first = normalizedImages.first {
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "image",
                    "moduleTitle": titles.image,
                    "imageURL": first,
                    "imageURLs": normalizedImages
                ])
            }
        case .split:
            for image in normalizedImages {
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "image",
                    "moduleTitle": titles.image,
                    "imageURL": image
                ])
            }
        }

        switch layout.code {
        case .grouped:
            if let first = normalizedCodeSnippets.first {
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "code",
                    "moduleTitle": titles.code,
                    "codeSnippet": first,
                    "codeSnippets": normalizedCodeSnippets
                ])
            }
        case .split:
            for code in normalizedCodeSnippets {
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "code",
                    "moduleTitle": titles.code,
                    "codeSnippet": code
                ])
            }
        }

        switch layout.link {
        case .grouped:
            if let first = normalizedLinks.first {
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "link",
                    "moduleTitle": titles.link,
                    "linkItem": first,
                    "linkItems": normalizedLinks
                ])
            }
        case .split:
            for link in normalizedLinks {
                fallback.append([
                    "id": UUID().uuidString,
                    "kind": "link",
                    "moduleTitle": titles.link,
                    "linkItem": link,
                    "linkItems": [link]
                ])
            }
        }

        return fallback
    }

    nonisolated static func normalizeModuleBlocks(
        _ raw: [String: Any],
        defaultLayout: ModuleLayoutSpec,
        defaultTitles: ModuleTitleSpec
    ) -> [[String: Any]] {
        let kind = (raw["type"] as? String ?? raw["kind"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kind.isEmpty else { return [] }

        switch kind {
        case "text":
            let textSegments = normalizeTextSegments(
                raw["texts"] ??
                    raw["textBlocks"] ??
                    raw["contentBlocks"] ??
                    raw["text"] ??
                    raw["content"]
            )
            guard !textSegments.isEmpty else { return [] }

            let explicitMode = raw["splitIntoBlocks"] ?? raw["distribution"] ?? raw["mode"]
            let hasTextArrayInput = raw["texts"] != nil || raw["textBlocks"] != nil || raw["contentBlocks"] != nil
            let defaultMode: ModuleDistributionMode = hasTextArrayInput ? .grouped : defaultLayout.text
            let mode = moduleDistributionMode(from: explicitMode, defaultMode: defaultMode)
            let perBlockTitles = normalizeStringArray(raw["textTitles"] ?? raw["moduleTitles"] ?? raw["blockTitles"])
            let primaryTitle = resolveModuleTitle(from: raw, defaultTitle: defaultTitles.text.first ?? "文本")

            switch mode {
            case .grouped:
                return [[
                    "id": (raw["id"] as? String) ?? UUID().uuidString,
                    "kind": "text",
                    "moduleTitle": primaryTitle,
                    "text": joinTextSegments(textSegments)
                ]]
            case .split:
                return textSegments.enumerated().map { index, segment in
                    [
                        "id": UUID().uuidString,
                        "kind": "text",
                        "moduleTitle": perBlockTitles.isEmpty
                            ? primaryTitle
                            : textModuleTitle(
                                at: index,
                                titles: perBlockTitles,
                                defaultTitle: defaultTitles.text.first ?? "文本"
                            ),
                        "text": segment
                    ]
                }
            }

        case "image":
            let imageSources = normalizeImageSourceArray(
                raw["imageURLs"] ??
                    raw["images"] ??
                    raw["urls"] ??
                    raw["imageURL"] ??
                    raw["imageUrl"] ??
                    raw["url"]
            )
            guard !imageSources.isEmpty else { return [] }

            let resolvedTitle = resolveModuleTitle(from: raw, defaultTitle: defaultTitles.image)
            let explicitMode = raw["splitIntoBlocks"] ?? raw["distribution"] ?? raw["mode"]
            let hasImageArrayInput = raw["imageURLs"] != nil || raw["images"] != nil || raw["urls"] != nil
            let defaultMode: ModuleDistributionMode = hasImageArrayInput ? .grouped : defaultLayout.image
            let mode = moduleDistributionMode(from: explicitMode, defaultMode: defaultMode)

            switch mode {
            case .grouped:
                guard let first = imageSources.first else { return [] }
                return [[
                    "id": (raw["id"] as? String) ?? UUID().uuidString,
                    "kind": "image",
                    "moduleTitle": resolvedTitle,
                    "imageURL": first,
                    "imageURLs": imageSources
                ]]
            case .split:
                return imageSources.map { source in
                    [
                        "id": UUID().uuidString,
                        "kind": "image",
                        "moduleTitle": resolvedTitle,
                        "imageURL": source
                    ]
                }
            }

        case "code":
            let snippets = normalizeCodeSnippetsFromModule(raw)
            guard !snippets.isEmpty else { return [] }

            let explicitMode = raw["splitIntoBlocks"] ?? raw["distribution"] ?? raw["mode"]
            let hasCodeArrayInput = raw["codeSnippets"] != nil
            let defaultMode: ModuleDistributionMode = hasCodeArrayInput ? .grouped : defaultLayout.code
            let mode = moduleDistributionMode(from: explicitMode, defaultMode: defaultMode)
            let resolvedTitle = resolveModuleTitle(from: raw, defaultTitle: defaultTitles.code)

            switch mode {
            case .grouped:
                guard let first = snippets.first else { return [] }
                return [[
                    "id": (raw["id"] as? String) ?? UUID().uuidString,
                    "kind": "code",
                    "moduleTitle": resolvedTitle,
                    "codeSnippet": first,
                    "codeSnippets": snippets
                ]]
            case .split:
                return snippets.map { snippet in
                    [
                        "id": UUID().uuidString,
                        "kind": "code",
                        "moduleTitle": resolvedTitle,
                        "codeSnippet": snippet
                    ]
                }
            }

        case "link":
            let normalizedLinks = normalizeLinksFromModule(raw)
            guard !normalizedLinks.isEmpty else { return [] }

            let explicitMode = raw["splitIntoBlocks"] ?? raw["distribution"] ?? raw["mode"]
            let hasLinkArrayInput = raw["linkItems"] != nil || raw["links"] != nil
            let defaultMode: ModuleDistributionMode = hasLinkArrayInput ? .grouped : defaultLayout.link
            let mode = moduleDistributionMode(from: explicitMode, defaultMode: defaultMode)
            let resolvedTitle = resolveModuleTitle(from: raw, defaultTitle: defaultTitles.link)

            switch mode {
            case .grouped:
                guard let first = normalizedLinks.first else { return [] }
                return [[
                    "id": (raw["id"] as? String) ?? UUID().uuidString,
                    "kind": "link",
                    "moduleTitle": resolvedTitle,
                    "linkItem": first,
                    "linkItems": normalizedLinks
                ]]
            case .split:
                return normalizedLinks.map { link in
                    [
                        "id": UUID().uuidString,
                        "kind": "link",
                        "moduleTitle": resolvedTitle,
                        "linkItem": link,
                        "linkItems": [link]
                    ]
                }
            }

        case "formula":
            let rawContent = (raw["text"] as? String ?? raw["content"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawContent.isEmpty else { return [] }
            let resolvedTitle = resolveModuleTitle(from: raw, defaultTitle: "公式")
            let normalizedContent = decodeEscapedControlSequencesDeterministically(rawContent)
            return [[
                "id": (raw["id"] as? String) ?? UUID().uuidString,
                "kind": "formula",
                "moduleTitle": resolvedTitle,
                "text": normalizedContent
            ]]

        default:
            return []
        }
    }

    nonisolated static func wrapLanguageTaggedXMLBlocks(_ text: String) -> String {
        let sourceLines = text.components(separatedBy: "\n")
        var output: [String] = []
        var index = 0
        var inFence = false

        while index < sourceLines.count {
            let line = sourceLines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inFence.toggle()
                output.append(line)
                index += 1
                continue
            }

            if !inFence && trimmed.lowercased() == "xml" {
                var probe = index + 1
                while probe < sourceLines.count && sourceLines[probe].trimmingCharacters(in: .whitespaces).isEmpty {
                    probe += 1
                }

                if probe < sourceLines.count && isLikelyXMLTagLine(sourceLines[probe]) {
                    var blockEnd = probe
                    while blockEnd < sourceLines.count {
                        let candidate = sourceLines[blockEnd]
                        let candidateTrimmed = candidate.trimmingCharacters(in: .whitespaces)
                        if candidateTrimmed.isEmpty || isLikelyXMLTagLine(candidate) {
                            blockEnd += 1
                        } else {
                            break
                        }
                    }

                    output.append("```xml")
                    output.append(contentsOf: sourceLines[probe..<blockEnd])
                    output.append("```")
                    index = blockEnd
                    continue
                }
            }

            output.append(line)
            index += 1
        }

        return output.joined(separator: "\n")
    }

    nonisolated static func escapeUnfencedXMLLines(_ text: String) -> String {
        let sourceLines = text.components(separatedBy: "\n")
        var output: [String] = []
        var inFence = false

        for line in sourceLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                output.append(line)
                continue
            }

            guard !inFence, isLikelyXMLTagLine(line) else {
                output.append(line)
                continue
            }

            output.append(escapeXMLLine(line))
        }

        return output.joined(separator: "\n")
    }

    nonisolated static func isLikelyXMLTagLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("<?xml"), trimmed.hasSuffix("?>") { return true }
        if trimmed.hasPrefix("<!--"), trimmed.hasSuffix("-->") { return true }
        if trimmed.hasPrefix("<!"), trimmed.hasSuffix(">") { return true }

        let pattern = #"^</?[A-Za-z_][A-Za-z0-9_\-:\.]*\b[^>]*?/?>$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return regex.firstMatch(in: trimmed, options: [], range: range) != nil
    }

    nonisolated static func escapeXMLLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    nonisolated static func collapseExtraBlankLines(
        _ text: String,
        maxConsecutiveBlankLines: Int
    ) -> String {
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []
        var blankCount = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankCount += 1
                if blankCount <= maxConsecutiveBlankLines + 1 {
                    output.append("")
                }
            } else {
                blankCount = 0
                output.append(line)
            }
        }

        return output.joined(separator: "\n")
    }
}
