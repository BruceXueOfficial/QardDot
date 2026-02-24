import Foundation

enum ImportImageSourceResolverError: Error {
    case invalidDataURI(reason: String)
    case invalidBase64(reason: String)
    case writeFailed(reason: String)

    var code: String {
        switch self {
        case .invalidDataURI:
            return "IMP-IMG-001"
        case .invalidBase64:
            return "IMP-IMG-002"
        case .writeFailed:
            return "IMP-IMG-003"
        }
    }

    var titleMessage: String {
        switch self {
        case .invalidDataURI:
            return "图片编码格式无效"
        case .invalidBase64:
            return "图片 Base64 数据无效"
        case .writeFailed:
            return "图片写入本地失败"
        }
    }

    var reason: String {
        switch self {
        case .invalidDataURI(let reason), .invalidBase64(let reason), .writeFailed(let reason):
            return reason
        }
    }

    var uiErrorMessage: String {
        "\(titleMessage)（错误码：\(code)，原因：\(reason)）"
    }
}

enum ImportImageSourceResolver {
    nonisolated static func materializeImageSources(in payload: [String: Any]) throws -> [String: Any] {
        var mutable = payload

        if let materializedModules = try materializeImageModules(from: mutable["modules"] ?? mutable["blocks"]) {
            mutable["modules"] = materializedModules
            mutable["blocks"] = materializedModules

            let legacyImages = collectLegacyImages(from: materializedModules, limit: 5)
            if legacyImages.isEmpty {
                mutable.removeValue(forKey: "images")
            } else {
                mutable["images"] = legacyImages
            }
            return mutable
        }

        let materializedTopLevel = try materializeImageSourceList(from: mutable["images"])
        if materializedTopLevel.isEmpty {
            mutable.removeValue(forKey: "images")
        } else {
            mutable["images"] = materializedTopLevel
        }
        return mutable
    }
}

private extension ImportImageSourceResolver {
    nonisolated static func materializeImageModules(from value: Any?) throws -> [[String: Any]]? {
        guard let rawModules = value as? [[String: Any]] else {
            return nil
        }

        return try rawModules.map { raw in
            var module = raw
            let kind = (module["kind"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard kind == "image" else {
                return module
            }

            let sourceValue: Any? = module["imageURLs"] ??
                module["images"] ??
                module["urls"] ??
                module["imageURL"] ??
                module["imageUrl"] ??
                module["url"]

            let materialized = try materializeImageSourceList(from: sourceValue)
            if materialized.isEmpty {
                module.removeValue(forKey: "imageURLs")
                module.removeValue(forKey: "imageURL")
                module.removeValue(forKey: "images")
                module.removeValue(forKey: "urls")
                module.removeValue(forKey: "imageUrl")
                module.removeValue(forKey: "url")
            } else {
                module["imageURLs"] = materialized
                module["imageURL"] = materialized.first
                module.removeValue(forKey: "images")
                module.removeValue(forKey: "urls")
                module.removeValue(forKey: "imageUrl")
                module.removeValue(forKey: "url")
            }

            return module
        }
    }

    nonisolated static func materializeImageSourceList(from value: Any?) throws -> [String] {
        let candidates = normalizedImageSourceCandidates(from: value)
        var output: [String] = []
        output.reserveCapacity(candidates.count)

        for candidate in candidates {
            let resolved = try materializeImageSource(candidate)
            if !resolved.isEmpty {
                output.append(resolved)
            }
        }

        return output
    }

    nonisolated static func normalizedImageSourceCandidates(from value: Any?) -> [String] {
        if let single = value as? String {
            let normalized = single.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? [] : [normalized]
        }

        if let array = value as? [String] {
            return array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let list = value as? [Any] {
            var result: [String] = []
            result.reserveCapacity(list.count)

            for item in list {
                if let source = item as? String {
                    let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalized.isEmpty {
                        result.append(normalized)
                    }
                    continue
                }

                if let object = item as? [String: Any],
                   let encoded = encodedImageObjectToDataURI(object) {
                    result.append(encoded)
                }
            }

            return result
        }

        if let object = value as? [String: Any],
           let encoded = encodedImageObjectToDataURI(object) {
            return [encoded]
        }

        return []
    }

    nonisolated static func encodedImageObjectToDataURI(_ object: [String: Any]) -> String? {
        let rawEncoding = (object["encoding"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

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

        let supportedBase64 = rawEncoding.isEmpty || rawEncoding == "base64" || rawEncoding == "b64"
        if supportedBase64 {
            let mimeType = normalizedMimeType(
                object["mimeType"] as? String ??
                    object["mime"] as? String ??
                    "image/jpeg"
            )
            return "data:\(mimeType);base64,\(rawData)"
        }

        if rawEncoding == "data_uri" || rawEncoding == "dataurl" || rawEncoding == "uri" {
            return rawData
        }

        return nil
    }

    nonisolated static func materializeImageSource(_ source: String) throws -> String {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return ""
        }

        guard normalized.lowercased().hasPrefix("data:") else {
            return normalized
        }

        let parsed = try parseDataURI(normalized)
        let base64Payload = parsed.base64Payload
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let decoded = Data(base64Encoded: base64Payload, options: [.ignoreUnknownCharacters]),
              !decoded.isEmpty else {
            throw ImportImageSourceResolverError.invalidBase64(reason: "无法解码 Base64 图片数据")
        }

        let fileURL = try persistImageData(decoded, mimeType: parsed.mimeType)
        return fileURL.absoluteString
    }

    nonisolated static func parseDataURI(_ source: String) throws -> (mimeType: String, base64Payload: String) {
        guard source.lowercased().hasPrefix("data:") else {
            throw ImportImageSourceResolverError.invalidDataURI(reason: "缺少 data: 前缀")
        }

        guard let commaIndex = source.firstIndex(of: ",") else {
            throw ImportImageSourceResolverError.invalidDataURI(reason: "缺少 data URI 分隔符逗号")
        }

        let metadataStart = source.index(source.startIndex, offsetBy: 5)
        let metadata = String(source[metadataStart..<commaIndex])
        let payload = String(source[source.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !payload.isEmpty else {
            throw ImportImageSourceResolverError.invalidDataURI(reason: "图片 payload 为空")
        }

        let segments = metadata
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let hasBase64 = segments.contains { $0.compare("base64", options: [.caseInsensitive]) == .orderedSame }
        guard hasBase64 else {
            throw ImportImageSourceResolverError.invalidDataURI(reason: "仅支持 base64 编码的 data URI")
        }

        let mimeType = segments.first(where: { $0.contains("/") }) ?? "image/jpeg"
        let normalizedMime = normalizedMimeType(mimeType)
        guard normalizedMime.hasPrefix("image/") else {
            throw ImportImageSourceResolverError.invalidDataURI(reason: "仅支持 image/* MIME 类型")
        }

        return (normalizedMime, payload)
    }

    nonisolated static func normalizedMimeType(_ raw: String) -> String {
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

    nonisolated static func persistImageData(_ data: Data, mimeType: String) throws -> URL {
        let fm = FileManager.default
        guard let documentsDirectory = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ImportImageSourceResolverError.writeFailed(reason: "无法定位文档目录")
        }

        let imageDirectory = documentsDirectory.appendingPathComponent("ModuleImages", isDirectory: true)
        do {
            try fm.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        } catch {
            throw ImportImageSourceResolverError.writeFailed(reason: "创建图片目录失败：\(error.localizedDescription)")
        }

        let fileURL = imageDirectory
            .appendingPathComponent("imported-image-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension(for: mimeType))

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw ImportImageSourceResolverError.writeFailed(reason: "写入图片文件失败：\(error.localizedDescription)")
        }
    }

    nonisolated static func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        case "image/heic":
            return "heic"
        case "image/heif":
            return "heif"
        case "image/bmp":
            return "bmp"
        case "image/tiff":
            return "tiff"
        case "image/avif":
            return "avif"
        default:
            return "jpg"
        }
    }

    nonisolated static func collectLegacyImages(from modules: [[String: Any]], limit: Int) -> [String] {
        let images = modules
            .filter {
                (($0["kind"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == "image"
            }
            .flatMap { module in
                if let array = module["imageURLs"] as? [String], !array.isEmpty {
                    return array
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
                if let single = (module["imageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !single.isEmpty {
                    return [single]
                }
                return []
            }

        return Array(images.prefix(max(limit, 0)))
    }
}
