import SwiftUI

struct ContentView: View {
    @AppStorage("selectedMechanismID") private var selectedMechanismID: String = JiaoBeiMechanism().id
    @State private var showingSettings = false

    private let mechanisms: [any DivinationMechanism] = [
        JiaoBeiMechanism(),
        FlowerPetalMechanism(),
        FortuneSticksMechanism(),
        SpinningWheelMechanism(),
        CoinFlipMechanism()
    ]

    private var selected: any DivinationMechanism {
        mechanisms.first(where: { $0.id == selectedMechanismID }) ?? mechanisms[0]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MechanismChipBar(
                    mechanisms: mechanisms,
                    selectedID: $selectedMechanismID
                )
                .padding(.top, 4)
                .padding(.bottom, 6)

                AnyView(selected.view())
            }
            .background(Theme.parchment.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("app.title")
                        .font(Theme.headlineSerif(20, weight: .semibold))
                        .foregroundStyle(Theme.cinnabarDeep)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.cinnabar)
                    }
                    .accessibilityLabel("settings.title")
                }
            }
            .toolbarBackground(Theme.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct MechanismChipBar: View {
    let mechanisms: [any DivinationMechanism]
    @Binding var selectedID: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(mechanisms, id: \.id) { m in
                        chip(for: m)
                            .id(m.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedID = m.id
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedID) { _, newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for m: any DivinationMechanism) -> some View {
        let isSelected = m.id == selectedID
        HStack(spacing: 6) {
            Image(systemName: m.iconName)
                .font(.system(size: 13, weight: .semibold))
            Text(m.displayName)
                .font(Theme.headlineSerif(15, weight: .semibold))
        }
        .foregroundStyle(isSelected ? Color.white : Theme.inkSoft)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Theme.cinnabar : Theme.parchmentDim.opacity(0.55))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Theme.gold : Theme.rule, lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
