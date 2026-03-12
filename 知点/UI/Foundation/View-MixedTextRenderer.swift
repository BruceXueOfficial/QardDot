import SwiftUI
import LaTeXSwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - MixedTextRenderer

/// Renders a string that may contain `$...$` or `$$...$$`-wrapped LaTeX formulas **inline**.
///
/// Rather than splitting the text into segments and stacking them vertically,
/// the entire string is passed directly to `LaTeX()` which handles inline
/// rendering natively — exactly like Gemini / ChatGPT style output.
///
/// - `parsingMode(.onlyEquations)` — parses `$...$` / `$$...$$` regions
/// - `blockMode(.alwaysInline)` — forces all equations (even `$$...$$`) to flow inline
/// - `imageRenderingMode(.template)` — formula images tint to match foreground (transparent bg)
/// - `.font(UIFont...)` — must use UIFont for correct formula scaling per LaTeXSwiftUI docs
struct MixedTextRenderer: View {
    let text: String

    /// Font size used for both body text and inline formulae.
    /// Adjust this single value to resize everything uniformly.
    var fontSize: CGFloat = 16
    
    /// Text color to render text and template-matching formulas.
    var textColor: Color = .primary
    
    /// Line spacing for the text block.
    var lineSpacing: CGFloat = 2.2

    // MARK: - Markdown Fixer
    
    /// Pre-process text to fix markdown parsing issues in LaTeXSwiftUI.
    /// LaTeXSwiftUI parses equations first, splitting the text into independent
    /// segments. For markdown tags (like `**...**`) that span across equations,
    /// the unmatched tags in the segments cause parsing to fail.
    /// This helper duplicates markdown tags around equations.
    private var processedText: String {
        // Step 1: Force all display math `$$...$$` to become inline math `$...$`
        // This ensures fractions and integrals use \textstyle sizing so they don't break line heights.
        var result = text.replacingOccurrences(of: "$$", with: "$")
        
        // Step 1.5: Inject \small to all math blocks to nicely scale them down relative to the body text
        let globalEqPattern = #"\$(.+?)\$"#
        if let globalEqRegex = try? NSRegularExpression(pattern: globalEqPattern, options: [.dotMatchesLineSeparators]) {
            let matches = globalEqRegex.matches(in: result, range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                let innerMath = (result as NSString).substring(with: match.range(at: 1))
                if !innerMath.hasPrefix("\\small") {
                    let newMath = "$\\small " + innerMath + "$"
                    result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: newMath)
                }
            }
        }
        
        // Step 2: Only fix `**...**` spans for now, as it's the most common
        let pattern = #"\*\*(.*?)\*\*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return result }
        
        let nsString = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))
        
        // Iterate backwards
        for match in matches.reversed() {
            let innerText = nsString.substring(with: match.range(at: 1))
            
            // Match $...$
            let eqPattern = #"(\$.+?\$)"#
            guard let eqRegex = try? NSRegularExpression(pattern: eqPattern, options: [.dotMatchesLineSeparators]),
                  eqRegex.numberOfMatches(in: innerText, range: NSRange(location: 0, length: (innerText as NSString).length)) > 0
            else { continue }
            
            let eqMatches = eqRegex.matches(in: innerText, range: NSRange(location: 0, length: (innerText as NSString).length))
            var newInner = ""
            var lastIndex = 0
            
            for eqMatch in eqMatches {
                let textBefore = (innerText as NSString).substring(with: NSRange(location: lastIndex, length: eqMatch.range.location - lastIndex))
                let eqText = (innerText as NSString).substring(with: eqMatch.range)
                
                newInner += wrapBold(textBefore)
                newInner += eqText
                lastIndex = eqMatch.range.location + eqMatch.range.length
            }
            
            let textAfter = (innerText as NSString).substring(from: lastIndex)
            newInner += wrapBold(textAfter)
            
            result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: newInner)
        }
        
        // Step 3: Hack to guarantee text-style fractions since \textstyle sometimes isn't enough in MathJax
        // We replace \frac with \tfrac (which forces inline text fraction mode without expanding line height)
        result = result.replacingOccurrences(of: "\\frac", with: "\\tfrac")

        // Step 4: Fallback rendering for Markdown lists and headings
        let lines = result.components(separatedBy: "\n")
        var processedLines = [String]()
        for line in lines {
            if let match = line.range(of: "^(\\s*)-[\\s]+", options: .regularExpression) {
                let prefixRange = line.range(of: "^(\\s*)", options: .regularExpression)!
                let spaceCount = line.distance(from: prefixRange.lowerBound, to: prefixRange.upperBound)
                
                let indentSpaces = String(repeating: "\u{2003}", count: max(0, spaceCount / 2))
                let bullet = spaceCount >= 4 ? "▪︎" : (spaceCount >= 2 ? "◦" : "•")
                let replacement = "\(indentSpaces)\(bullet) "
                processedLines.append(line.replacingCharacters(in: match, with: replacement))
            } else if let match = line.range(of: "^(#{1,6})\\s+", options: .regularExpression) {
                let title = String(line[match.upperBound...])
                processedLines.append("**\(title)**")
            } else {
                processedLines.append(line)
            }
        }
        result = processedLines.joined(separator: "\n")
        
        return result
    }
    
    /// Wraps text in `**`, keeping leading and trailing spaces outside the tags
    private func wrapBold(_ text: String) -> String {
        var coreText = text
        var leadingSpaces = ""
        var trailingSpaces = ""
        
        while coreText.hasPrefix(" ") || coreText.hasPrefix("\n") {
            leadingSpaces += String(coreText.removeFirst())
        }
        while coreText.hasSuffix(" ") || coreText.hasSuffix("\n") {
            trailingSpaces += String(coreText.removeLast())
        }
        
        if coreText.isEmpty { return text }
        return leadingSpaces + "**" + coreText + "**" + trailingSpaces
    }

    var body: some View {
        LaTeX(processedText)
            .parsingMode(.onlyEquations)
            .blockMode(.alwaysInline)
            .imageRenderingMode(.template)
            .renderingStyle(.wait)
            .errorMode(.original)
            .foregroundStyle(textColor)
            .font(.system(size: fontSize))
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("Mixed Text Renderer") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Inline formula within text
            MixedTextRenderer(
                text: "23 个人之间可以产生 $\\frac{23 \\times 22}{2}$ 对组合，每一对都有可能撞生日，这样机会就大大增加了。"
            )

            Divider()

            // Inline + block formulas mixed with body text
            MixedTextRenderer(
                text: "生日悖论的核心概率：$P(\\text{不同}) = \\frac{365}{365} \\times \\frac{364}{365} \\times \\dots \\times \\frac{343}{365} \\approx 0.4927$，因此至少两人同生日的概率约为 **50.73%**。"
            )

            Divider()

            // Classic equations inline
            MixedTextRenderer(
                text: "勾股定理 $a^2 + b^2 = c^2$ 与欧拉恒等式 $e^{i\\pi} + 1 = 0$ 是数学中最美的公式之一。"
            )

            Divider()

            // Plain text — no formulas, renders as normal body text
            MixedTextRenderer(text: "这是一段纯文本，没有任何公式，应该正常展示。")
        }
        .padding(20)
    }
}
