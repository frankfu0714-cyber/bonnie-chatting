import SwiftUI

/// One way of helping the user reach a decision. Each concrete mechanism is
/// responsible for its own UI — `view()` returns a fresh SwiftUI view bound
/// to nothing outside its scope. The mechanism objects themselves are stateless
/// descriptors held in a list at the navigation root.
protocol DecisionMechanism: Identifiable {
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
