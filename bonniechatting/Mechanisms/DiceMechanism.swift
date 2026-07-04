import SwiftUI

/// 骰子 — classic Western d6 dice. User chooses 1–6 dice; tap to roll. Each
/// die tumbles for ~1.2s before settling to a random face (1–6). Reveal card
/// shows individual faces and the sum.
struct DiceMechanism: DecisionMechanism {
    let id = "dice"
    var displayName: LocalizedStringKey { "mechanism.dice.name" }
    let iconName = "dice.fill"

    func view() -> AnyView {
        AnyView(DiceView())
    }
}
