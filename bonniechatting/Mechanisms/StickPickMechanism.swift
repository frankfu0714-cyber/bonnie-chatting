import SwiftUI

/// Stick Pick — a cylinder of numbered wooden sticks. The user provides a
/// list of possible answers; shaking the cylinder makes one stick fall out,
/// and the stick's position in the list maps to the picked answer. Pure
/// random picker — the mechanism assigns no meaning of its own.
struct StickPickMechanism: DecisionMechanism {
    let id = "stickpick"
    var displayName: LocalizedStringKey { "mechanism.stickpick.name" }
    let iconName = "list.number"

    func view() -> AnyView {
        AnyView(StickPickView())
    }
}

enum StickNumeral {
    static let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// Convert 1...99 to its traditional Chinese numeral; falls back to base-10.
    /// Used as decorative typography on each stick's tip — the sticks are
    /// numbered from one to N so the falling stick can be identified visually.
    static func of(_ n: Int) -> String {
        guard n > 0 else { return digits[0] }
        if n < 10 { return digits[n] }
        if n == 10 { return "十" }
        if n < 20 { return "十" + digits[n - 10] }
        if n < 100 {
            let tens = n / 10
            let ones = n % 10
            return digits[tens] + "十" + (ones == 0 ? "" : digits[ones])
        }
        return "\(n)"
    }

    /// Locale-aware numeral for the reveal label: Chinese for zh locales,
    /// Arabic digits otherwise.
    static func localized(_ n: Int, locale: Locale) -> String {
        locale.identifier.hasPrefix("zh") ? of(n) : String(n)
    }
}
