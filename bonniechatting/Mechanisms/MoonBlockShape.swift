import SwiftUI

/// A real-temple 筊杯 silhouette: a "D" — flat bottom edge and a half-circle arc
/// above. The flat edge is the divination face; the arc is the rounded back.
/// The same outline is used regardless of which side is up — `MoonBlockView`
/// switches the surface treatment (flat painted face vs. domed back with a
/// gloss highlight) so the viewer can read each block's orientation.
struct MoonBlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Flat diametral edge across the bottom of the rect.
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Cubic curve back to the start, arching over the top. Control points
        // are pulled outward and slightly above the top edge so the resulting
        // curve approximates a true semicircle when rect is ~2:1 (W:H).
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

/// A single moon block. `.flat` shows the painted flat face — uniform burgundy
/// with a faint inner ring and a tiny carved centre dot. `.curved` shows the
/// rounded back — burgundy gradient with a thin gloss strip ~25% from the top
/// of the arc, suggesting lacquered depth.
struct MoonBlockView: View {
    let face: BlockFace
    /// Visual rotation applied after the toss settles (random, for variety).
    var rotation: Angle = .zero
    /// During the toss the block tumbles — separate from `rotation` so the
    /// settled angle persists after animation ends.
    var tumble: Angle = .zero
    var translation: CGSize = .zero
    /// Default is ~2:1 to match real moon blocks.
    var size: CGSize = CGSize(width: 150, height: 78)

    var body: some View {
        ZStack {
            // Drop shadow on the ground beneath the block.
            Ellipse()
                .fill(Theme.woodShadow.opacity(0.28))
                .frame(width: size.width * 0.85, height: 12)
                .offset(y: size.height * 0.62)
                .blur(radius: 6)

            ZStack {
                // Body fill
                MoonBlockShape()
                    .fill(faceFill)
                // Surface treatment (gloss strip or carved-face cue)
                faceHighlight
                    .mask(MoonBlockShape())
                // Outline
                MoonBlockShape()
                    .stroke(Theme.lacquerEdge.opacity(0.85), lineWidth: 1.2)
            }
            .frame(width: size.width, height: size.height)
            .shadow(color: Theme.woodShadow.opacity(0.35), radius: 4, x: 1, y: 3)
            .rotationEffect(rotation + tumble)
        }
        .offset(translation)
    }

    private var faceFill: LinearGradient {
        switch face {
        case .flat:
            // Flat face: nearly uniform burgundy, slight cool→warm tilt.
            return LinearGradient(
                colors: [Theme.lacquerMid, Theme.lacquerLow],
                startPoint: .top,
                endPoint: .bottom
            )
        case .curved:
            // Curved face: bright at the dome apex (top), dark at the flat edge (bottom).
            return LinearGradient(
                colors: [Theme.lacquerHi, Theme.lacquerMid, Theme.lacquerLow, Theme.lacquerEdge],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder private var faceHighlight: some View {
        switch face {
        case .flat:
            // Subtle inner darker ring near the edge + a tiny carved centre dot,
            // suggesting we're looking straight down at a flat painted top.
            ZStack {
                MoonBlockShape()
                    .stroke(Theme.lacquerEdge.opacity(0.35), lineWidth: 6)
                    .blur(radius: 4)
                Circle()
                    .fill(Theme.lacquerEdge.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .offset(y: -size.height * 0.05)
            }
        case .curved:
            // Gloss strip ~25% from the top of the curved face.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0),
                                 Color.white.opacity(0.55),
                                 Color.white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size.width * 0.72, height: size.height * 0.10)
                .offset(y: -size.height * 0.22)
                .blur(radius: 2)
        }
    }
}
