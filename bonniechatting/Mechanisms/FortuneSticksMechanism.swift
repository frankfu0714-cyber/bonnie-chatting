import SwiftUI

/// 求籤 — bamboo fortune sticks in a cylinder. The user provides a list of
/// possible answers; shaking the cylinder makes one stick fall out, mapping
/// (by Chinese-numeral position) to the chosen answer.
struct FortuneSticksMechanism: DivinationMechanism {
    let id = "sticks"
    var displayName: LocalizedStringKey { "mechanism.sticks.name" }
    let iconName = "list.number"

    func view() -> AnyView {
        AnyView(FortuneSticksView())
    }
}

enum ChineseNumeral {
    static let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// Convert 1...99 to its traditional Chinese numeral; falls back to base-10.
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
}
