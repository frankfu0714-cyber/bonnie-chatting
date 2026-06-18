import SwiftUI

/// 花瓣 — "loves me, loves me not" with a configurable number of petals.
/// Each pluck alternates between two custom labels; the last petal standing
/// is the answer.
struct FlowerPetalMechanism: DivinationMechanism {
    let id = "petals"
    var displayName: LocalizedStringKey { "mechanism.petals.name" }
    let iconName = "camera.macro"

    func view() -> AnyView {
        AnyView(FlowerPetalView())
    }
}
