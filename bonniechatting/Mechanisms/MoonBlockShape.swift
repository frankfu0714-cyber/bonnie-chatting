import SwiftUI

/// Clean half-moon silhouette: perfectly straight flat edge, semicircle dome.
/// Modern flat-graphic style (think temple-stationary sticker), not
/// photorealistic wood. The same outline is used for both face-up states —
/// orientation reads from the carved centre dot on the flat face.
struct MoonBlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Flat diametral edge across the bottom of the rect.
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Cubic curve back to the start — control points pulled outward and
        // slightly above the top edge so the curve approximates a true
        // semicircle when rect is sized 2:1 (W:H).
        let lift = rect.height * 0.34
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY - lift),
            control2: CGPoint(x: rect.minX, y: rect.minY - lift)
        )
        p.closeSubpath()
        return p
    }
}

/// A thin curved arc that follows the inner edge of the block's dome — a
/// stylised highlight suggesting light from above. Drawn separately so we
/// can stroke it with a fading gradient, giving soft endpoints.
struct MoonBlockHighlightArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Endpoints sit ~22% in from the block's left/right edges, about
        // halfway down the rect. Control points pull up above the rect so
        // the cubic peaks ~17% from the top — visually hugging the inner
        // edge of the dome.
        let inset = w * 0.22
        let endY = rect.minY + h * 0.50
        let ctrlY = rect.minY - h * 0.10
        p.move(to: CGPoint(x: rect.minX + inset, y: endY))
        p.addCurve(
            to: CGPoint(x: rect.maxX - inset, y: endY),
            control1: CGPoint(x: rect.minX + inset, y: ctrlY),
            control2: CGPoint(x: rect.maxX - inset, y: ctrlY)
        )
        return p
    }
}

/// A single moon block, rendered in modern flat-graphic style. Cinnabar
/// red body with a subtle vertical gradient and a thin curved highlight
/// hugging the inner top edge. Flat-face-up shows a small carved centre
/// dot to make orientation readable in the toss reveal.
struct MoonBlockView: View {
    let face: BlockFace
    /// Persistent rotation after the toss settles.
    var rotation: Angle = .zero
    /// In-flight rotation during the toss.
    var tumble: Angle = .zero
    var translation: CGSize = .zero
    /// 2:1 aspect so the dome reads as a true semicircle.
    var size: CGSize = CGSize(width: 150, height: 75)

    var body: some View {
        ZStack {
            MoonBlockShape()
                .fill(bodyFill)
                .overlay(
                    MoonBlockHighlightArc()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0),
                                         Color(red: 1, green: 0.96, blue: 0.90).opacity(0.75),
                                         Color.white.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                )
                .overlay(
                    MoonBlockShape()
                        .stroke(Theme.mbRedDeep.opacity(0.55), lineWidth: 0.8)
                )
                .frame(width: size.width, height: size.height)

            if face == .flat {
                // Carved centre dot — subtle reading cue for flat-face-up.
                Circle()
                    .fill(Theme.mbRedDeep.opacity(0.70))
                    .frame(width: 4.5, height: 4.5)
                    .offset(y: -size.height * 0.05)
            }
        }
        .rotationEffect(rotation + tumble)
        .offset(translation)
    }

    /// Subtle vertical gradient. Same for both faces — orientation reads
    /// from the carved dot, not from shading.
    private var bodyFill: LinearGradient {
        LinearGradient(
            colors: [Theme.mbRedLight, Theme.mbRed, Theme.mbRedDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
