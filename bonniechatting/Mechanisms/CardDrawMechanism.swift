import SwiftUI

/// 抽卡片 — a deck of cards. The user provides a list of options; drawing
/// makes one card slide out from the top of the stack and flip over to reveal
/// the chosen option.
struct CardDrawMechanism: DecisionMechanism {
    let id = "carddraw"
    var displayName: LocalizedStringKey { "mechanism.carddraw.name" }
    let iconName = "rectangle.stack.fill"

    func view() -> AnyView {
        AnyView(CardDrawView())
    }
}
