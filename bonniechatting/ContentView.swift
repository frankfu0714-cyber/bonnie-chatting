import SwiftUI

struct ContentView: View {
    @AppStorage("selectedMechanismID") private var selectedMechanismID: String = MagicEightBallMechanism().id
    @State private var showingSettings = false

    private let mechanisms: [any DecisionMechanism] = [
        MagicEightBallMechanism(),
        FlowerPetalMechanism(),
        TissueMechanism(),
        CardDrawMechanism(),
        SpinningWheelMechanism(),
        CoinFlipMechanism(),
        RandomNumberMechanism(),
        DiceMechanism(),
        TwoPieceTossMechanism(),
        StickPickMechanism()
    ]

    private var selected: any DecisionMechanism {
        mechanisms.first(where: { $0.id == selectedMechanismID }) ?? mechanisms[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom title bar — tighter than the standard nav bar so the
            // chip row sits closer to the title, leaving more viewport
            // room for the mechanism content below.
            HStack {
                Spacer().frame(width: 36)
                Spacer()
                Text("app.title")
                    .font(Theme.headlineSerif(20, weight: .semibold))
                    .foregroundStyle(Theme.cinnabarDeep)
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.cinnabar)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("settings.title")
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 2)

            MechanismChipBar(
                mechanisms: mechanisms,
                selectedID: $selectedMechanismID
            )
            .padding(.top, 2)
            .padding(.bottom, 6)

            AnyView(selected.view())
        }
        .background(Theme.parchment.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .presentationDetents([.medium])
        }
    }
}

private struct MechanismChipBar: View {
    let mechanisms: [any DecisionMechanism]
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
    private func chip(for m: any DecisionMechanism) -> some View {
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
