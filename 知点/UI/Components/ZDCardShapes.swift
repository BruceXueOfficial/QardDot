import SwiftUI

struct TitleCardPunchedShape: Shape {
    let cornerRadius: CGFloat
    let holeSize: CGFloat
    let holeInset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        let holeOriginX = rect.maxX - holeInset - holeSize
        let holeOriginY = rect.minY + holeInset
        let holeRect = CGRect(x: holeOriginX, y: holeOriginY, width: holeSize, height: holeSize)
        path.addEllipse(in: holeRect)
        return path
    }
}

struct KnowledgeCardPinHoleInnerShadow: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat = 13

    var body: some View {
        Circle()
            .stroke(Color.black.opacity(colorScheme == .dark ? 0.86 : 0.72), lineWidth: 1.65)
            .blur(radius: 0.26)
            .offset(y: 0.36)
            .mask(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.black.opacity(1.0), .black.opacity(0.38), .clear],
                            center: .center,
                            startRadius: size * 0.12,
                            endRadius: size * 0.58
                        )
                    )
            )
            .frame(width: size, height: size)
    }
}

#Preview("Punched Card Shape") {
    ZStack {
        Color.zdPageBase.ignoresSafeArea()

        TitleCardPunchedShape(cornerRadius: 24, holeSize: 16, holeInset: 14)
            .fill(LinearGradient.zdCardStandardTLBR, style: FillStyle(eoFill: true))
            .frame(width: 300, height: 170)
            .overlay {
                TitleCardPunchedShape(cornerRadius: 24, holeSize: 16, holeInset: 14)
                    .stroke(Color.zdAccentDeep.opacity(0.4), lineWidth: 0.9)
            }
    }
}

#Preview("Pin Hole Inner Shadow") {
    ZStack {
        Color.zdPageBase.ignoresSafeArea()

        Circle()
            .fill(Color.white)
            .frame(width: 56, height: 56)
            .overlay {
                KnowledgeCardPinHoleInnerShadow(size: 18)
            }
    }
}
