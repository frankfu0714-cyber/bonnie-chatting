import SwiftUI

/// 轉盤 — spinning prize-wheel divided into N user-defined wedges. The pointer
/// at the top of the screen indicates which wedge the wheel lands on.
struct SpinningWheelMechanism: DecisionMechanism {
    let id = "wheel"
    var displayName: LocalizedStringKey { "mechanism.wheel.name" }
    let iconName = "dial.medium"

    func view() -> AnyView {
        AnyView(SpinningWheelView())
    }
}
