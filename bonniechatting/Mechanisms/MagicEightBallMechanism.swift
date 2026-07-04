import SwiftUI

/// Magic 8-Ball — the iconic Western decision helper. User shakes; a triangular
/// window on the underside reveals one of three outcomes (Yes / Maybe / No).
struct MagicEightBallMechanism: DecisionMechanism {
    let id = "magic8ball"
    var displayName: LocalizedStringKey { "mechanism.magic8ball.name" }
    let iconName = "8.circle.fill"

    func view() -> AnyView {
        AnyView(MagicEightBallView())
    }
}

/// Three semantic slots — matches the historical yes/laugh/no ternary that
/// existed in v1.0.0, so the user's customized labels can carry over.
enum EightBallOutcome: String, CaseIterable {
    case yes
    case maybe
    case no

    var titleKey: LocalizedStringKey {
        switch self {
        case .yes:   return "magic8ball.outcome.yes.title"
        case .maybe: return "magic8ball.outcome.maybe.title"
        case .no:    return "magic8ball.outcome.no.title"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .yes:   return "magic8ball.outcome.yes.desc"
        case .maybe: return "magic8ball.outcome.maybe.desc"
        case .no:    return "magic8ball.outcome.no.desc"
        }
    }

    var defaultUserLabelKey: LocalizedStringKey {
        switch self {
        case .yes:   return "magic8ball.outcome.yes.default_label"
        case .maybe: return "magic8ball.outcome.maybe.default_label"
        case .no:    return "magic8ball.outcome.no.default_label"
        }
    }
}
