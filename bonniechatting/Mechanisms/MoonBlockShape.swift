import SwiftUI

/// True half-moon silhouette: flat edge perfectly straight at the bottom,
/// dome is a perfect semicircle. Built from two quarter-arc cubic Beziers
/// with the standard k≈0.5523 circle approximation (max error <0.03%).
struct MoonBlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width / 2, rect.height)
        let cx = rect.midX
        let baseY = rect.maxY
        let k: CGFloat = 0.5522847498

        p.move(to: CGPoint(x: cx - r, y: baseY))
        // Left-quarter arc: base → top
        p.addCurve(
            to: CGPoint(x: cx, y: baseY - r),
            control1: CGPoint(x: cx - r,     y: baseY - k * r),
            control2: CGPoint(x: cx - k * r, y: baseY - r)
        )
        // Right-quarter arc: top → base
        p.addCurve(
            to: CGPoint(x: cx + r, y: baseY),
            control1: CGPoint(x: cx + k * r, y: baseY - r),
            control2: CGPoint(x: cx + r,     y: baseY - k * r)
        )
        p.closeSubpath()
        return p
    }
}

/// A single moon block. Flat-graphic style: solid cinnabar fill, one thin
/// curved highlight on the upper arc, optional carved centre dot on the
/// flat-face side. No outline, no shadow, no perspective tilt.
struct MoonBlockView: View {
    let face: BlockFace
    var rotation: Angle = .zero
    var tumble: Angle = .zero
    var translation: CGSize = .zero
    var size: CGSize = CGSize(width: 150, height: 75)

    var body: some View {
        ZStack {
            // Solid cinnabar body — true semicircle.
            MoonBlockShape()
                .fill(Theme.mbRed)
                .frame(width: size.width, height: size.height)

            // Gloss highlight only on the CURVED face — the flat painted
            // face wouldn't catch light the same way the rounded back does.
            if face == .curved {
                highlight
            }

            // Carved centre dot — orientation cue for flat-face-up.
            if face == .flat {
                Circle()
                    .fill(Color.black.opacity(0.30))
                    .frame(width: 4, height: 4)
                    .offset(y: -size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(rotation + tumble)
        .offset(translation)
    }

    private var highlight: some View {
        GeometryReader { geo in
            let r = min(geo.size.width / 2, geo.size.height)
            let inset: CGFloat = 7
            let ringD = max(2 * (r - inset), 0)

            // Top arc segment, ~70° wide centred on 12 o'clock — kept tight
            // so it reads as a single highlight, not a wrap-around stroke.
            // Circle's path: t=0 at 3 o'clock, increasing clockwise.
            // 10:30 ≈ t = 0.660, 12:00 = 0.750, 1:30 ≈ 0.840.
            Circle()
                .trim(from: 0.660, to: 0.840)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0),    location: 0.660),
                            .init(color: Color.white.opacity(0.70), location: 0.750),
                            .init(color: Color.white.opacity(0),    location: 0.840)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: ringD, height: ringD)
                .position(x: geo.size.width / 2, y: geo.size.height)
        }
    }
}
