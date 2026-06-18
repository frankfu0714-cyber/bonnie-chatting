import SwiftUI

@main
struct BonnieChattingApp: App {

    /// The user's chosen UI language ("zh" / "en") — empty means follow system.
    /// Stored so it takes effect on next launch; the env-locale below gives
    /// us same-session updates for the strings that respect it.
    @AppStorage("uiLanguage") private var uiLanguage: String = ""

    init() {
        // Pin nav-title text to brand ink so the warm-paper background reads cleanly
        // even when the device is in dark mode.
        let ink = UIColor(red: 0.20, green: 0.13, blue: 0.10, alpha: 1.0)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: ink]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: ink]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, currentLocale)
                .tint(Theme.cinnabar)
        }
    }

    private var currentLocale: Locale {
        switch uiLanguage {
        case "zh": return Locale(identifier: "zh-Hant")
        case "en": return Locale(identifier: "en")
        default:   return Locale.current
        }
    }
}
