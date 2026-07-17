import SwiftUI

/// Two-Piece Toss — two crescent-profile blocks with a flat side and a curved
/// side. Tossing them together produces one of three physical outcomes
/// (both flat up, both curved up, or one of each). The user assigns their
/// own label to each outcome — the mechanism is a pure random picker.
struct TwoPieceTossMechanism: DecisionMechanism {
    let id = "twopiece"
    var displayName: LocalizedStringKey { "mechanism.twopiece.name" }
    let iconName = "moon.fill"

    func view() -> AnyView {
        AnyView(TwoPieceTossView())
    }
}

/// The three physical outcomes of a two-block toss.
enum TossOutcome: String, CaseIterable {
    /// One flat side up, one curved side up.
    case mixed
    /// Both flat sides up.
    case bothFlat
    /// Both curved sides up.
    case bothCurved

    /// Short physical descriptor shown as a small pill above the user label.
    var nameKey: LocalizedStringKey {
        switch self {
        case .mixed:       return "twopiece.outcome.mixed.name"
        case .bothFlat:    return "twopiece.outcome.both_flat.name"
        case .bothCurved:  return "twopiece.outcome.both_curved.name"
        }
    }

    /// Default user-facing label (Yes / Maybe / No), before customization.
    var defaultUserLabelKey: LocalizedStringKey {
        switch self {
        case .mixed:       return "twopiece.outcome.mixed.default_label"
        case .bothFlat:    return "twopiece.outcome.both_flat.default_label"
        case .bothCurved:  return "twopiece.outcome.both_curved.default_label"
        }
    }
}

/// One block's face after landing.
enum BlockFace {
    case flat
    case curved
}

extension TossOutcome {
    static func from(_ a: BlockFace, _ b: BlockFace) -> TossOutcome {
        switch (a, b) {
        case (.flat, .flat):     return .bothFlat
        case (.curved, .curved): return .bothCurved
        default:                 return .mixed
        }
    }
}
