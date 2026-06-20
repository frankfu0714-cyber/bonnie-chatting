import SwiftUI

/// A real-temple 筊杯 silhouette. Proper crescent moon proportions: the top
/// arcs outward strongly; the bottom arcs *inward* slightly so the "flat"
/// edge isn't a hard straight line. Same outline regardless of which side
/// is up — `MoonBlockView` switches the surface treatment so the viewer
/// can read each block's orientation (flat-up vs curved-up).
struct MoonBlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Subtle inward arc on the "flat" side (~10% of height upward at
        // centre) — matches real temple jiao bei, which are gently scooped
        // rather than perfectly flat.
        let flatArcDepth = rect.height * 0.10
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - flatArcDepth)
        )
        // Outer dome arc back to start — control points pulled outward and
        // above the rect to approximate a true semicircle.
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

/// A single moon block, rendered with 3D-leaning depth cues:
/// - `.curved`: looking down at the dome-shaped back. Strong directional fill
///   from a hot specular crest at the top arc to deep shadow at the flat
///   bottom edge, plus a thin bright gloss strip near the crest.
/// - `.flat`: looking down at the painted divination face. Bevelled
///   chamfer around the perimeter, faint inner highlight, tiny carved
///   centre dot.
/// Both faces sit on a soft cast shadow on the parchment beneath them.
struct MoonBlockView: View {
    let face: BlockFace
    /// Persistent rotation after a toss settles.
    var rotation: Angle = .zero
    /// In-flight rotation during the toss.
    var tumble: Angle = .zero
    var translation: CGSize = .zero
    /// ~2:1 aspect to match real moon blocks.
    var size: CGSize = CGSize(width: 150, height: 78)

    var body: some View {
        ZStack {
            // Soft cast shadow on the parchment beneath the block. Larger
            // and softer than the SwiftUI .shadow modifier so the block
            // reads as a physical object sitting on the surface.
            Ellipse()
                .fill(Theme.woodShadow.opacity(0.42))
                .frame(width: size.width * 1.05, height: 18)
                .offset(y: size.height * 0.66)
                .blur(radius: 9)

            ZStack {
                // Body fill — directional gradient.
                MoonBlockShape()
                    .fill(faceFill)
                // Surface treatment (gloss strip / bevel / carved dot), masked.
                faceHighlight
                    .mask(MoonBlockShape())
                // Outline.
                MoonBlockShape()
                    .stroke(Theme.lacquerEdge.opacity(0.95), lineWidth: 1.2)
            }
            .frame(width: size.width, height: size.height)
            // Tight contact shadow nudging the block off the surface.
            .shadow(color: Theme.woodShadow.opacity(0.45), radius: 3, x: 1, y: 2)
            .rotationEffect(rotation + tumble)
        }
        .offset(translation)
    }

    // MARK: - Fills

    /// Curved-face body fill: top-down LinearGradient with strong tonal range
    /// suggesting a rounded surface lit from above.
    /// Flat-face body fill: gentler, more uniform burgundy.
    private var faceFill: LinearGradient {
        switch face {
        case .flat:
            return LinearGradient(
                colors: [
                    Theme.lacquerMid,
                    Theme.lacquerMid,
                    Theme.lacquerLow
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .curved:
            return LinearGradient(
                colors: [
                    Theme.lacquerSpec,
                    Theme.lacquerHi,
                    Theme.lacquerMid,
                    Theme.lacquerLow,
                    Theme.lacquerEdge
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Surface treatment

    @ViewBuilder private var faceHighlight: some View {
        switch face {
        case .flat:
            flatFaceTreatment
        case .curved:
            curvedFaceTreatment
        }
    }

    /// Painted flat face: subtle bevelled edge, faint top sheen catching
    /// light, and the small carved centre indentation.
    private var flatFaceTreatment: some View {
        ZStack {
            // Dark chamfer around the perimeter — the painted edge of the block.
            MoonBlockShape()
                .stroke(Theme.lacquerEdge.opacity(0.55), lineWidth: 5)
                .blur(radius: 3)

            // Faint top-edge sheen — a soft horizontal smear of light along
            // the curved upper edge where light catches the bevel.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.20), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.55
                    )
                )
                .frame(width: size.width * 0.85, height: size.height * 0.40)
                .offset(y: -size.height * 0.22)
                .blendMode(.plusLighter)

            // Carved centre indentation: dark dot with a tiny highlight rim above,
            // suggesting a shallow carved pit.
            ZStack {
                Circle()
                    .fill(Theme.lacquerEdge.opacity(0.85))
                    .frame(width: 6, height: 6)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
                    .frame(width: 6, height: 6)
                    .offset(y: -0.5)
            }
            .offset(y: -size.height * 0.05)
        }
    }

    /// Curved-face back: bright thin gloss strip near the crest, a secondary
    /// off-axis highlight, and a dark inner shadow along the bottom edge
    /// suggesting the wood wrapping away from the viewer.
    private var curvedFaceTreatment: some View {
        ZStack {
            // Bright gloss strip ~22% from the top arc — the brightest specular.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0),
                                 Color.white.opacity(0.85),
                                 Color.white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size.width * 0.66, height: size.height * 0.09)
                .offset(y: -size.height * 0.24)
                .blur(radius: 2)
                .blendMode(.plusLighter)

            // Wide warm highlight halo behind the gloss strip — adds tonal
            // depth and reads as a rounded surface catching ambient light.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.50
                    )
                )
                .frame(width: size.width * 0.92, height: size.height * 0.55)
                .offset(y: -size.height * 0.10)
                .blendMode(.plusLighter)

            // Dark inner shadow along the bottom flat edge — the back of the
            // block curving away. Thin band hugging the flat baseline.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear,
                                 Color.clear,
                                 Theme.lacquerEdge.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: size.height)
                .blendMode(.multiply)

            // Subtle off-axis right-side specular smear — light wrapping
            // around the curve on the right.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.16), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.25
                    )
                )
                .frame(width: size.width * 0.30, height: size.height * 0.30)
                .offset(x: size.width * 0.22, y: -size.height * 0.05)
                .blendMode(.plusLighter)
        }
    }
}
