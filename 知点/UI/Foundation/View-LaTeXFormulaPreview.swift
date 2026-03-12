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

#Preview("Card Detail - 生日悖论 LaTeX 渲染") {
    let card = KnowledgeCard(
        title: "生日悖论（Birthday Paradox）是什么？",
        content: "",
        type: .long,
        blocks: [
            .text("我们在潜意识里通常只考虑“其他人和我生日相同”的概率，而忽略了“房间里任意两个人之间生日相同”的概率。23 个人之间可以产生 $$\\frac{23 \\times 22}{2} = 253$$ 对组合，每一对都有可能撞生日，这样机会就大大增加了。"),
            .text("### 背后的数学逻辑\n\n在计算时，直接算“至少两个人同生日”比较复杂，所以数学上通常反过来算：**这 23 个人的生日全都不相同的概率是多少？**"),
            .text("• 第 1 个人的生日可以是 365 天中的任意一天，概率是 $$\\frac{365}{365}$$。\n\n• 第 2 个人要想和第 1 个人不同，只能选剩下的 364 天，概率是 $$\\frac{364}{365}$$。\n\n• 第 3 个人要想和前两人都不同，只能选剩下的 363 天，概率是 $$\\frac{363}{365}$$。\n\n• 以此类推，**第 23 个人不和前面任何人同生日的概率是 $$\\frac{343}{365}$$。**"),
            .text("所以，**“这 23 个人生日全都不相同”**的总概率是所有的分数相乘："),
            .text("$$P(\\text{均不相同}) = \\frac{365}{365} \\times \\frac{364}{365} \\times \\dots \\times \\frac{343}{365} \\approx 0.4927$$"),
            .text("那么，**“至少有两个人同生日”**的概率就是 $1$ 减去上面的结果："),
            .text("$$P(\\text{至少两人相同}) = 1 - 0.4927 = 0.5073$$"),
            .text("结论：只要屋子里有 **23** 人，就有大概约 **50.73%** 的概率找到两个生日相同的人！是不是很反直觉？")
        ]
    )
    
    // We wrap it in a ZStack simulating the background of the app
    ZStack {
        Color.black.ignoresSafeArea()
        // Use KnowledgeCardDetailDrawerPreviewHost to render the card full screen with correct environment
        KnowledgeCardDetailDrawerPreviewHost(card: card)
    }
}
