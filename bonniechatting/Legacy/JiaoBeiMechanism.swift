import SwiftUI

/// 筊杯 (jiao bei / moon blocks). Two crescent-shaped wooden pieces with one
/// flat face and one curved face each. Tossed together; the combination of
/// faces-up gives a yes / laugh / no answer.
struct JiaoBeiMechanism: DivinationMechanism {
    let id = "jiaobei"
    var displayName: LocalizedStringKey { "mechanism.jiaobei.name" }
    let iconName = "moon.fill"

    func view() -> AnyView {
        AnyView(JiaoBeiView())
    }
}

/// The three canonical outcomes. Each block has two possible orientations
/// (flat-up or curved-up); the *combination* of the pair is what matters.
enum JiaoBeiOutcome: String, CaseIterable {
    /// 聖筊 — one flat, one curved. Affirmative.
    case sheng
    /// 笑筊 — both flat (so the curved bellies sit up showing the round backs).
    /// Wait — convention varies. We follow the common Taiwanese reading:
    ///   flat side up = "smile" side, both up = laughing blocks (笑筊).
    /// Both flat-faces up = laughing.
    case xiao
    /// 陰筊 — both curved up (flat down). Negative.
    case yin

    /// Headline label (localized key).
    var titleKey: LocalizedStringKey {
        switch self {
        case .sheng: return "jiaobei.outcome.sheng.title"
        case .xiao:  return "jiaobei.outcome.xiao.title"
        case .yin:   return "jiaobei.outcome.yin.title"
        }
    }

    /// Traditional Chinese name (聖筊 / 笑筊 / 陰筊).
    var nameKey: LocalizedStringKey {
        switch self {
        case .sheng: return "jiaobei.outcome.sheng.name"
        case .xiao:  return "jiaobei.outcome.xiao.name"
        case .yin:   return "jiaobei.outcome.yin.name"
        }
    }

    /// Brief description of what this combination traditionally means.
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .sheng: return "jiaobei.outcome.sheng.desc"
        case .xiao:  return "jiaobei.outcome.xiao.desc"
        case .yin:   return "jiaobei.outcome.yin.desc"
        }
    }

    /// Default user-facing answer label, before they customize it.
    var defaultUserLabelKey: LocalizedStringKey {
        switch self {
        case .sheng: return "jiaobei.outcome.sheng.default_label"
        case .xiao:  return "jiaobei.outcome.xiao.default_label"
        case .yin:   return "jiaobei.outcome.yin.default_label"
        }
    }
}

/// One block's face after a toss.
enum BlockFace {
    case flat   // 平面朝上
    case curved // 圓面朝上
}

extension JiaoBeiOutcome {
    /// Resolve a pair of block faces into one of the three outcomes.
    /// Both flat-up → 笑筊; both curved-up → 陰筊; one of each → 聖筊.
    static func from(_ a: BlockFace, _ b: BlockFace) -> JiaoBeiOutcome {
        switch (a, b) {
        case (.flat, .flat):     return .xiao
        case (.curved, .curved): return .yin
        default:                 return .sheng
        }
    }
}
