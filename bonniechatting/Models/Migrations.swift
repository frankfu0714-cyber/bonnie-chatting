import Foundation

/// One-time key migrations run on app launch. Each entry is idempotent —
/// re-running is safe because the write is gated on the destination key
/// being empty. A `migrationsApplied` bump flag prevents needless work.
enum Migrations {

    private static let appliedKey = "migrations.v1_0_1.applied"

    static func run() {
        let ud = UserDefaults.standard
        guard !ud.bool(forKey: appliedKey) else { return }

        // 筊杯 → Magic 8-Ball: carry over the three custom outcome labels.
        // Semantic slots map: sheng → yes, xiao → maybe, yin → no.
        moveString(from: "jiaobei.label.sheng", to: "magic8ball.label.yes")
        moveString(from: "jiaobei.label.xiao",  to: "magic8ball.label.maybe")
        moveString(from: "jiaobei.label.yin",   to: "magic8ball.label.no")

        // 求籤 → Card Draw: carry over the question and the option list.
        moveString(from: "sticks.question", to: "carddraw.question")
        moveString(from: "sticks.options",  to: "carddraw.options")

        // Selected mechanism id.
        if let sel = ud.string(forKey: "selectedMechanismID") {
            switch sel {
            case "jiaobei": ud.set("magic8ball", forKey: "selectedMechanismID")
            case "sticks":  ud.set("carddraw",   forKey: "selectedMechanismID")
            default: break
            }
        }

        ud.set(true, forKey: appliedKey)
    }

    private static func moveString(from oldKey: String, to newKey: String) {
        let ud = UserDefaults.standard
        guard let old = ud.string(forKey: oldKey), !old.isEmpty else { return }
        // Only write if the user hasn't already set a value under the new key.
        let existing = ud.string(forKey: newKey) ?? ""
        if existing.isEmpty {
            ud.set(old, forKey: newKey)
        }
        ud.removeObject(forKey: oldKey)
    }
}
