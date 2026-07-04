import SwiftUI

/// 銅板 — single Chinese square-hole coin (方孔錢). Two faces:
/// 字 (text-side, traditionally bearing the era inscription) and
/// 幕 (back, traditionally blank). Common shorthand in folk divination
/// for yes / no.
struct CoinFlipMechanism: DecisionMechanism {
    let id = "coin"
    var displayName: LocalizedStringKey { "mechanism.coin.name" }
    let iconName = "centsign.circle.fill"

    func view() -> AnyView {
        AnyView(CoinFlipView())
    }
}
