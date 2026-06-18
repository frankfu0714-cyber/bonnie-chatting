import SwiftUI

struct ContentView: View {
    @State private var selectedMechanismID: String = JiaoBeiMechanism().id

    private let mechanisms: [any DivinationMechanism] = [
        JiaoBeiMechanism()
        // v0.2+: FortuneSticksMechanism(), SpinningWheelMechanism(), CoinFlipMechanism()
    ]

    private var selected: any DivinationMechanism {
        mechanisms.first(where: { $0.id == selectedMechanismID }) ?? mechanisms[0]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.parchment.ignoresSafeArea()

                AnyView(selected.view())
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("app.title")
                        .font(Theme.headlineSerif(20, weight: .semibold))
                        .foregroundStyle(Theme.cinnabarDeep)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("picker.mechanism", selection: $selectedMechanismID) {
                            ForEach(mechanisms, id: \.id) { m in
                                Label(m.displayName, systemImage: m.iconName)
                                    .tag(m.id)
                            }
                        }
                    } label: {
                        Image(systemName: selected.iconName)
                            .foregroundStyle(Theme.cinnabar)
                    }
                }
            }
            .toolbarBackground(Theme.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
}
