import SwiftUI

/// One way of asking the deities for guidance. v0.1 ships JiaoBei only;
/// v0.2+ will add fortune sticks (籤), a spinning wheel (轉盤), and coin flip.
///
/// Each concrete mechanism is responsible for its own UI — `view()` returns a
/// fresh SwiftUI view bound to nothing outside its scope. The mechanism objects
/// themselves are stateless descriptors held in a list at the navigation root.
protocol DivinationMechanism: Identifiable {
    /// Stable identifier persisted in `@AppStorage` so the user's last pick
    /// can be restored across launches.
    var id: String { get }

    /// Localized name for menus and pickers — return a `LocalizedStringKey`
    /// that resolves against the catalog.
    var displayName: LocalizedStringKey { get }

    /// SF Symbol used in the toolbar / picker.
    var iconName: String { get }

    /// Build the mechanism's screen. Use `AnyView` at the call site so the
    /// protocol stays existential-friendly.
    @ViewBuilder func view() -> AnyView
}
