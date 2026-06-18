import SwiftUI

/// A hand-carved-looking crescent moon block. The shape is a vertically-stretched
/// teardrop: wide and rounded at the bottom (the "belly"), tapered at the top.
/// We use the same outline for both faces — `flat` vs `curved` is conveyed by
/// the fill (lighter wood gradient with a subtle inner highlight vs. darker
/// wood gradient with a domed shadow).
struct MoonBlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX

        // Start at the top apex.
        p.move(to: CGPoint(x: cx, y: rect.minY + h * 0.06))
        // Right side curves out to the belly, then around the bottom.
        p.addCurve(
            to: CGPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.62),
            control1: CGPoint(x: rect.minX + w * 0.85, y: rect.minY + h * 0.10),
            control2: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.40)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.maxY - h * 0.02),
            control1: CGPoint(x: rect.maxX - w * 0.05, y: rect.maxY - h * 0.06),
            control2: CGPoint(x: rect.minX + w * 0.70, y: rect.maxY - h * 0.01)
        )
        // Mirror on the left side back up to the apex.
        p.addCurve(
            to: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.62),
            control1: CGPoint(x: rect.minX + w * 0.30, y: rect.maxY - h * 0.01),
            control2: CGPoint(x: rect.minX + w * 0.05, y: rect.maxY - h * 0.06)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY + h * 0.06),
            control1: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.40),
            control2: CGPoint(x: rect.minX + w * 0.15, y: rect.minY + h * 0.10)
        )
        p.closeSubpath()
        return p
    }
}

/// A single moon block rendered as a face — `.flat` shows the lighter top
/// (the side you'd press into ink), `.curved` shows the rounder back with
/// a domed highlight.
struct MoonBlockView: View {
    let face: BlockFace
    /// Visual rotation applied after the toss settles (random, for variety).
    var rotation: Angle = .zero
    /// During the toss the block tumbles — separate from `rotation` so the
    /// settled angle persists after animation ends.
    var tumble: Angle = .zero
    var translation: CGSize = .zero
    var size: CGSize = CGSize(width: 110, height: 150)

    var body: some View {
        ZStack {
            // Drop shadow on the ground beneath the block.
            Ellipse()
                .fill(Theme.woodShadow.opacity(0.28))
                .frame(width: size.width * 0.85, height: 14)
                .offset(y: size.height * 0.50)
                .blur(radius: 6)

            MoonBlockShape()
                .fill(faceFill)
                .overlay(
                    MoonBlockShape()
                        .stroke(Theme.woodDark.opacity(0.55), lineWidth: 1.2)
                )
                .overlay(faceHighlight)
                .frame(width: size.width, height: size.height)
                .shadow(color: Theme.woodShadow.opacity(0.35), radius: 4, x: 1, y: 3)
                .rotationEffect(rotation + tumble)
        }
        .offset(translation)
    }

    private var faceFill: LinearGradient {
        switch face {
        case .flat:
            return LinearGradient(
                colors: [Theme.woodLight, Theme.woodMid, Theme.woodMid.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .curved:
            return LinearGradient(
                colors: [Theme.woodMid, Theme.woodDark, Theme.woodShadow],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder private var faceHighlight: some View {
        switch face {
        case .flat:
            // Long woodgrain streaks on the flat face.
            MoonBlockShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear, Theme.woodDark.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width, height: size.height)
        case .curved:
            // Domed highlight near the top of the curved back.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: size.width * 0.55
                    )
                )
                .frame(width: size.width * 0.78, height: size.height * 0.55)
                .offset(y: -size.height * 0.08)
        }
    }
}
