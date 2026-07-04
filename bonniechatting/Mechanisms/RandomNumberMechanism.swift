import SwiftUI

/// 隨機數字 — pick a uniform-random integer from a user-defined range.
/// Visualized as a slot-reel that scrambles for ~0.9s before landing on
/// the final value.
struct RandomNumberMechanism: DecisionMechanism {
    let id = "random"
    var displayName: LocalizedStringKey { "mechanism.random.name" }
    let iconName = "number"

    func view() -> AnyView {
        AnyView(RandomNumberView())
    }
}
