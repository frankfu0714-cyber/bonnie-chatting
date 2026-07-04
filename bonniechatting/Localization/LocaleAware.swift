import SwiftUI

extension String {
    /// Look up a localized string using an explicit locale, bypassing
    /// `Bundle.main.preferredLocalizations`. Required for call sites that
    /// must respect the app's in-app `\.environment(\.locale)` override —
    /// `NSLocalizedString` reads the device's preferred languages, not the
    /// env override, so without this helper a string seeded via
    /// `NSLocalizedString` stays in the device language even when the user
    /// has toggled the in-app language picker.
    static func appLocalized(_ key: String, locale: Locale) -> String {
        let lang: String
        let identifier = locale.identifier
        if identifier.hasPrefix("zh") {
            lang = "zh-Hant"
        } else if identifier.hasPrefix("en") {
            lang = "en"
        } else {
            // Fall back to source language for any other locale.
            lang = "zh-Hant"
        }
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
