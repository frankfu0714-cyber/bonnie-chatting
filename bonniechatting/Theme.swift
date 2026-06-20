import SwiftUI

/// Sacred-temple palette: aged paper, cinnabar red, warm gold, wood browns.
/// The named accent color lives in `Assets.xcassets/AccentColor.colorset`
/// and matches `cinnabar` below.
enum Theme {

    // MARK: - Surfaces (aged paper / parchment)
    static let parchment    = Color(red: 0.96, green: 0.90, blue: 0.78)  // #F5E6C8 — primary background
    static let parchmentDim = Color(red: 0.91, green: 0.84, blue: 0.71)
    static let card         = Color(red: 0.985, green: 0.94, blue: 0.83)

    // MARK: - Ink (deep brown for primary text)
    static let ink          = Color(red: 0.20, green: 0.13, blue: 0.10)
    static let inkSoft      = Color(red: 0.36, green: 0.26, blue: 0.20)
    static let inkQuiet     = Color(red: 0.52, green: 0.42, blue: 0.34)
    static let rule         = Color(red: 0.78, green: 0.66, blue: 0.50).opacity(0.45)

    // MARK: - Brand
    static let cinnabar     = Color(red: 0.545, green: 0.180, blue: 0.165) // #8B2E2A — 朱紅
    static let cinnabarDeep = Color(red: 0.42,  green: 0.11,  blue: 0.10)
    static let gold         = Color(red: 0.785, green: 0.663, blue: 0.360) // #C8A95C — 金
    static let goldDeep     = Color(red: 0.60,  green: 0.47,  blue: 0.20)

    // MARK: - Wood (general — used for fortune sticks, coin edges, shadows, etc.)
    static let woodLight    = Color(red: 0.72, green: 0.50, blue: 0.30)
    static let woodMid      = Color(red: 0.55, green: 0.34, blue: 0.18)
    static let woodDark     = Color(red: 0.34, green: 0.19, blue: 0.10)
    static let woodShadow   = Color(red: 0.18, green: 0.10, blue: 0.05)

    // MARK: - Lacquer (deep red lacquered wood — real temple moon blocks)
    /// Brightest specular along the dome crest.
    static let lacquerSpec  = Color(red: 0.70, green: 0.30, blue: 0.30) // warm highlight under gloss
    /// Highlight along the curve's apex.
    static let lacquerHi    = Color(red: 0.55, green: 0.18, blue: 0.18) // brighter burgundy for top sheen
    /// Main body — rich burgundy.
    static let lacquerMid   = Color(red: 0.478, green: 0.118, blue: 0.145) // ~#7A1E25
    /// Shadowed underside of the dome.
    static let lacquerLow   = Color(red: 0.361, green: 0.094, blue: 0.125) // ~#5C1820
    /// Outline + deepest shadow.
    static let lacquerEdge  = Color(red: 0.227, green: 0.051, blue: 0.063) // ~#3A0D10

    // MARK: - Fonts
    /// Headline serif: tries `Songti TC` first (traditional look), falls back to system serif.
    static func headlineSerif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if UIFont(name: "Songti TC", size: size) != nil {
            return .custom("Songti TC", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension View {
    /// Parchment background applied to the full screen.
    func parchmentBackground() -> some View {
        background(
            ZStack {
                Theme.parchment
                // Soft vignette to suggest aged paper
                RadialGradient(
                    colors: [Color.clear, Theme.parchmentDim.opacity(0.55)],
                    center: .center,
                    startRadius: 120,
                    endRadius: 520
                )
            }
            .ignoresSafeArea()
        )
    }
}
