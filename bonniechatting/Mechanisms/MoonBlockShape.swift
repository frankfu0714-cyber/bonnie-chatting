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
                // Body fill — flat cinnabar on the painted side, dome
                // radial gradient on the curved side suggesting 3D form.
                MoonBlockShape()
                    .fill(bodyFill)

                // Gloss highlight only on the curved face.
                if face == .curved {
                    highlight
                }

                // Carved centre dot — orientation cue for flat-face-up.
                if face == .flat {
                    Circle()
                        .fill(Color.black.opacity(0.32))
                        .frame(width: 4.5, height: 4.5)
                        .offset(y: -size.height * 0.05)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .rotationEffect(rotation + tumble)
        .offset(translation)
    }

    /// Vivid cinnabar. The curved face uses a RadialGradient centred on
    /// the visual middle of the crescent — the physical apex is highest
    /// in the centre, so ALL edges (left/right tips AND top/bottom) curve
    /// away from the viewer and read darker. The flat face stays
    /// near-uniform.
    private var bodyFill: AnyShapeStyle {
        switch face {
        case .flat:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Theme.mbRed, Theme.mbRedDeep.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .curved:
            return AnyShapeStyle(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Theme.mbRedLight,  location: 0.00),
                        .init(color: Theme.mbRed,       location: 0.45),
                        .init(color: Theme.mbRedDeep,   location: 0.85),
                        .init(color: Theme.mbRedShadow, location: 1.00)
                    ]),
                    // Visual centre of the crescent sits slightly above the
                    // rect midpoint because the inward arc on the bottom
                    // pulls the silhouette upward.
                    center: UnitPoint(x: 0.5, y: 0.40),
                    startRadius: 2,
                    // Tightened so the dark shadow tone reaches the upper
                    // corners (where the dome arc meets the tips), not just
                    // beyond them.
                    endRadius: size.width * 0.40
                )
            )
        }
    }

    /// Wider curved highlight (6pt) hugging the upper arc. AngularGradient
    /// fades at both ends so the highlight has soft edges, not hard endpoints.
    private var highlight: some View {
        GeometryReader { geo in
            let r = min(geo.size.width / 2, geo.size.height)
            let inset: CGFloat = 9
            let ringD = max(2 * (r - inset), 0)

            // Narrow ~36° arc centred on 12 o'clock — sits only over the
            // top middle of the dome so it doesn't bleed onto the upper
            // corners (which need to read dark, not lit).
            // 11 o'clock ≈ t = 0.700, 12 o'clock = 0.750, 1 o'clock ≈ 0.800.
            Circle()
                .trim(from: 0.700, to: 0.800)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0),    location: 0.700),
                            .init(color: Color.white.opacity(0.35), location: 0.750),
                            .init(color: Color.white.opacity(0),    location: 0.800)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: ringD, height: ringD)
                .position(x: geo.size.width / 2, y: geo.size.height)
        }
    }
}
