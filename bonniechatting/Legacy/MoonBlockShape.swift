import SwiftUI

/// Crescent silhouette — outer arc strongly convex, inner ("flat") edge
/// concave with a pronounced inward bow. Matches the temple-poster reference:
/// a banana/quarter-moon profile with pointed tips at the left and right.
struct MoonBlockShape: Shape {
    /// Bow depth of the inner edge as a fraction of `rect.height`.
    /// 0 → straight flat edge (half-moon). 0.30 → pronounced crescent.
    var flatArcDepth: CGFloat = 0.30

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width / 2, rect.height)
        let cx = rect.midX
        let baseY = rect.maxY
        let k: CGFloat = 0.5522847498  // cubic Bezier circle approximation

        // Start at the left tip.
        p.move(to: CGPoint(x: cx - r, y: baseY))

        // Concave inner edge (the "flat" side) — arcs upward at centre.
        let bow = rect.height * flatArcDepth
        p.addQuadCurve(
            to: CGPoint(x: cx + r, y: baseY),
            control: CGPoint(x: cx, y: baseY - bow)
        )

        // Right-quarter outer arc: right tip → top.
        p.addCurve(
            to: CGPoint(x: cx, y: baseY - r),
            control1: CGPoint(x: cx + r,     y: baseY - k * r),
            control2: CGPoint(x: cx + k * r, y: baseY - r)
        )

        // Left-quarter outer arc: top → left tip.
        p.addCurve(
            to: CGPoint(x: cx - r, y: baseY),
            control1: CGPoint(x: cx - k * r, y: baseY - r),
            control2: CGPoint(x: cx - r,     y: baseY - k * r)
        )

        p.closeSubpath()
        return p
    }
}

/// A single moon block. Vivid cinnabar fill with a soft 3D-leaning dome
/// gradient on the curved-face side, plus a wider curved gloss highlight
/// hugging the outer arc. Flat-face side stays flat (no highlight, no
/// dome gradient) — just the carved orientation dot. Sits on a soft cast
/// shadow at rest.
struct MoonBlockView: View {
    let face: BlockFace
    var rotation: Angle = .zero
    var tumble: Angle = .zero
    var translation: CGSize = .zero
    var size: CGSize = CGSize(width: 150, height: 78)

    var body: some View {
        ZStack {
            // Soft cast shadow on the parchment beneath the block.
            Ellipse()
                .fill(Color.black.opacity(0.20))
                .frame(width: size.width * 0.92, height: 10)
                .offset(y: size.height * 0.62)
                .blur(radius: 7)

            ZStack {
                if face == .curved {
                    curvedFaceBody
                } else {
                    flatFaceBody
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .rotationEffect(rotation + tumble)
        .offset(translation)
    }

    // MARK: - Curved face (glossy, dimensional)

    @ViewBuilder private var curvedFaceBody: some View {
        // Dark outer crescent — base shadow tone surrounding the inner moon.
        MoonBlockShape()
            .fill(Theme.mbRedDeep)

        // Bright inner crescent, scaled and blurred so it reads as a
        // smaller moon glowing inside the larger one. Tighter blur (12pt)
        // than before so the bright region stays distinct, and the vivid
        // mbRedGlow pop colour makes it pop.
        MoonBlockShape()
            .fill(Theme.mbRedGlow)
            .scaleEffect(0.60)
            .blur(radius: 12)
            .mask(MoonBlockShape())

        // Bold gloss highlight at the top middle of the dome.
        glossHighlight

        // Tiny secondary specular catching off-axis light on the upper-right.
        Circle()
            .fill(Color.white.opacity(0.45))
            .frame(width: 4, height: 4)
            .blur(radius: 1)
            .offset(x: size.width * 0.18, y: -size.height * 0.28)
    }

    /// Bold (~9pt) curved highlight hugging the upper arc.
    private var glossHighlight: some View {
        GeometryReader { geo in
            let r = min(geo.size.width / 2, geo.size.height)
            let inset: CGFloat = 9
            let ringD = max(2 * (r - inset), 0)

            Circle()
                .trim(from: 0.700, to: 0.800)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0),    location: 0.700),
                            .init(color: Color.white.opacity(0.55), location: 0.750),
                            .init(color: Color.white.opacity(0),    location: 0.800)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .frame(width: ringD, height: ringD)
                .position(x: geo.size.width / 2, y: geo.size.height)
        }
    }

    // MARK: - Flat face (matte, recessed, big carved dot)

    @ViewBuilder private var flatFaceBody: some View {
        // Solid matte cinnabar — deliberately less vivid than the curved
        // face so the two states read clearly different.
        MoonBlockShape()
            .fill(Theme.mbRedMatte)

        // Soft inset shadow around the perimeter — suggests the flat
        // surface sits down inside the block rather than bulging up.
        MoonBlockShape()
            .stroke(Color.black.opacity(0.30), lineWidth: 3)
            .blur(radius: 1.5)
            .mask(MoonBlockShape())

        // Carved centre pit — bigger and darker than before, with a top
        // shadow rim + bottom highlight rim so it reads as recessed
        // (light from above hits the far inside edge of the pit).
        ZStack {
            Circle()
                .fill(Theme.mbDotDark)
                .frame(width: 11, height: 11)
            // Top of pit — overhead light blocked.
            Circle()
                .trim(from: 0.55, to: 0.95)
                .stroke(Color.black.opacity(0.45), lineWidth: 1.2)
                .frame(width: 10, height: 10)
            // Bottom inside the pit — far surface catches light.
            Circle()
                .trim(from: 0.05, to: 0.45)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: 10, height: 10)
        }
        .offset(y: -size.height * 0.05)
    }
}
