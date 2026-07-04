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

    // MARK: - Moon block (筊杯) — vivid temple cinnabar.
    /// Vivid pop colour for the inner-moon glow on the curved face.
    static let mbRedGlow    = Color(red: 0.949, green: 0.353, blue: 0.271) // ~#F25A45
    /// Bright dome top — used for the curved-face gradient highlight.
    static let mbRedLight   = Color(red: 0.875, green: 0.290, blue: 0.220) // ~#DF4A38
    /// Main cinnabar fill — vivid vermillion (matches temple poster reference).
    static let mbRed        = Color(red: 0.831, green: 0.231, blue: 0.169) // ~#D43A2C
    /// Shaded lower curve / outline accent.
    static let mbRedDeep    = Color(red: 0.604, green: 0.149, blue: 0.122) // ~#9A261F
    /// Deepest shadow — used at the very edge of the curved-face radial.
    static let mbRedShadow  = Color(red: 0.486, green: 0.129, blue: 0.133) // ~#7C2122
    /// Matte cinnabar — the dull painted FLAT-face colour, deliberately
    /// less vivid than `mbRed` so it reads distinctly flatter.
    static let mbRedMatte   = Color(red: 0.573, green: 0.188, blue: 0.149) // ~#923026
    /// Deep colour used for the carved orientation pit on the flat face.
    static let mbDotDark    = Color(red: 0.353, green: 0.094, blue: 0.094) // ~#5A1818

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
