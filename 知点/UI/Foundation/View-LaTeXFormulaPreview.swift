import SwiftUI
import LaTeXSwiftUI

/// A lightweight wrapper that renders a LaTeX string using
/// the LaTeXSwiftUI package.  Falls back to a plain-text label
/// when the source string is empty or rendering fails.
struct LaTeXFormulaPreview: View {
    let latex: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LaTeX(latex)
                .parsingMode(.all)
                .blockMode(.alwaysInline)
                .foregroundStyle(.primary)
                .font(.body)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("LaTeX Formula Preview") {
    VStack(spacing: 20) {
        LaTeXFormulaPreview(latex: "E = mc^2")
        LaTeXFormulaPreview(latex: "\\frac{1}{2}mv^2")
        LaTeXFormulaPreview(latex: "\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}")
    }
    .padding()
}
