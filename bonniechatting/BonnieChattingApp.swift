import SwiftUI

@main
struct BonnieChattingApp: App {

    /// The user's chosen UI language. One of: "system" (follow device),
    /// "en", or "zh-Hant". Bound to the Settings sheet's language picker;
    /// changes here re-render the whole UI via `.environment(\.locale, ...)`.
    @AppStorage("preferredLocale") private var preferredLocale: String = "system"

    init() {
        Migrations.run()

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
        switch preferredLocale {
        case "en":     return Locale(identifier: "en")
        case "zh-Hant": return Locale(identifier: "zh-Hant")
        default:       return .autoupdatingCurrent
        }
    }
}
