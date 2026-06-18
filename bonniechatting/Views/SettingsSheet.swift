import SwiftUI

/// Settings sheet — currently houses just the language toggle. The picked
/// value is the canonical `preferredLocale` AppStorage key consumed by
/// `BonnieChattingApp` to set `\.locale` on the scene root.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// "system" — follow device language
    /// "en"     — force English
    /// "zh-Hant" — force Traditional Chinese
    @AppStorage("preferredLocale") private var preferredLocale: String = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("settings.language.label", selection: $preferredLocale) {
                        Text("settings.language.system").tag("system")
                        Text("settings.language.english").tag("en")
                        Text("settings.language.chinese").tag("zh-Hant")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("settings.language.label")
                } footer: {
                    Text("settings.language.footer")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
