import SwiftUI

/// 抽面紙 — pull tissues one at a time from a box. Same alternating-pluck UX
/// as the flower-petal mechanism but with a tactile "tug" instead of a delicate
/// pluck. Tissue count per round is randomized (10...20) so parity counting
/// can't be used to pre-compute the final answer.
struct TissueMechanism: DivinationMechanism {
    let id = "tissues"
    var displayName: LocalizedStringKey { "mechanism.tissues.name" }
    let iconName = "square.stack.3d.up"

    func view() -> AnyView {
        AnyView(TissueView())
    }
}
