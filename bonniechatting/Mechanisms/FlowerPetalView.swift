import SwiftUI

struct FlowerPetalView: View {

    // MARK: - Per-question state (persists)

    @AppStorage("petals.question")   private var question: String = ""
    @AppStorage("petals.labelYes")   private var labelYes: String = ""
    @AppStorage("petals.labelNo")    private var labelNo: String = ""
    @AppStorage("petals.count")      private var petalCount: Int = 7

    @FocusState private var questionFocused: Bool
    @State private var showingSettings = false

    // MARK: - Round state

    /// One petal in the current round.
    private struct Petal: Identifiable, Equatable {
        let id: Int
        var plucked: Bool
        /// Random tilt applied to the petal's "flutter" exit animation.
        var exitTilt: Double
        var exitOffset: CGSize
    }
    @State private var petals: [Petal] = []
    /// Whether the *first* pluck registers as "yes" (true) or "no" (false).
    /// Randomized each round so the user can't pre-compute the answer from
    /// petal-count parity.
    @State private var firstPluckYes: Bool = true
    @State private var pluckCount: Int = 0
    @State private var revealedLabel: String?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                questionCard
                settingsCard
                stage
                if let label = revealedLabel {
                    revealCard(label: label)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                actionButton
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear { if petals.isEmpty { startNewRound() } }
        .sheet(isPresented: $showingSettings) {
            FlowerSettingsSheet(
                labelYes: $labelYes,
                labelNo: $labelNo,
                petalCount: $petalCount
            ) {
                startNewRound()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("petals.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)

            TextField("petals.question.placeholder", text: $question, axis: .vertical)
                .font(Theme.headlineSerif(19, weight: .regular))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...3)
                .focused($questionFocused)
                .submitLabel(.done)
                .onSubmit { questionFocused = false }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var settingsCard: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(labelOrDefault(labelYes, default: defaultYes))
                            .font(Theme.body(14, weight: .semibold))
                            .foregroundStyle(Theme.cinnabarDeep)
                        Text("／")
                            .foregroundStyle(Theme.inkQuiet)
                        Text(labelOrDefault(labelNo, default: defaultNo))
                            .font(Theme.body(14, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Text(verbatim: "\(petalCount) " + petalCountLabel)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkQuiet)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkQuiet)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.parchmentDim.opacity(0.55))
            )
        }
        .buttonStyle(.plain)
    }

    private var petalCountLabel: String {
        // Quick localized count helper.
        NSLocalizedString("petals.count.label", comment: "")
    }

    private var stage: some View {
        let total = petals.count
        return ZStack {
            // Decorative ground ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.25), Theme.parchment.opacity(0)],
                        center: .center,
                        startRadius: 30,
                        endRadius: 180
                    )
                )
                .frame(height: 320)

            // Center bud (yellow disc).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold, Theme.goldDeep],
                        center: .center,
                        startRadius: 4,
                        endRadius: 40
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Circle().stroke(Theme.cinnabarDeep.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Theme.woodShadow.opacity(0.18), radius: 4, x: 0, y: 2)

            // Petals — one per index, positioned around the center.
            ForEach(petals) { petal in
                petalView(petal, total: total)
            }

            // Next-pluck hint
            if revealedLabel == nil, petals.contains(where: { !$0.plucked }) {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 12, weight: .semibold))
                        Text("petals.next_hint")
                            .font(Theme.body(12, weight: .semibold))
                        Text("→")
                        Text(nextLabel)
                            .font(Theme.headlineSerif(14, weight: .semibold))
                            .foregroundStyle(Theme.cinnabarDeep)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.card.opacity(0.92)))
                    .overlay(Capsule().stroke(Theme.gold.opacity(0.55), lineWidth: 0.8))
                    .foregroundStyle(Theme.inkSoft)
                }
                .padding(.bottom, 4)
            }
        }
        .frame(height: 340)
    }

    private func petalView(_ petal: Petal, total: Int) -> some View {
        let angle = Double(petal.id) / Double(total) * 360.0 - 90.0
        let radius: CGFloat = 110
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        let baseRotation = angle + 90

        // Wrap each petal as a Button: Buttons handle hit-testing reliably
        // inside ScrollViews (where plain .onTapGesture can lose taps), and
        // a Button's tap region is its label's frame. We force a 60×100
        // label frame so the tap target is bigger than the petal's visual
        // 36×80, giving a small forgiveness margin.
        return Button {
            pluck(petal)
        } label: {
            PetalShape()
                .fill(
                    LinearGradient(
                        colors: petal.plucked
                            ? [Theme.parchmentDim, Theme.parchmentDim.opacity(0.5)]
                            : [Color(red: 0.88, green: 0.45, blue: 0.42),
                               Theme.cinnabar],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    PetalShape().stroke(Theme.cinnabarDeep.opacity(0.35), lineWidth: 0.8)
                )
                .frame(width: 36, height: 80)
                .shadow(color: Theme.woodShadow.opacity(0.15), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(baseRotation + (petal.plucked ? petal.exitTilt : 0)))
                .opacity(petal.plucked ? 0 : 1)
                .scaleEffect(petal.plucked ? 0.7 : 1)
                .frame(width: 60, height: 100)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(
            x: x + (petal.plucked ? petal.exitOffset.width : 0),
            y: y + (petal.plucked ? petal.exitOffset.height : 0)
        )
        .allowsHitTesting(!petal.plucked)
    }

    private func revealCard(label: String) -> some View {
        VStack(spacing: 10) {
            Text("petals.reveal.title")
                .font(Theme.body(12, weight: .semibold))
                .foregroundStyle(Theme.inkQuiet)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(label.isEmpty ? "—" : label)
                .font(Theme.headlineSerif(26, weight: .bold))
                .foregroundStyle(Theme.cinnabarDeep)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.cinnabar.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Theme.woodShadow.opacity(0.18), radius: 8, x: 0, y: 4)
        )
    }

    private var actionButton: some View {
        Button {
            startNewRound()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                Text(revealedLabel == nil ? "petals.action.fresh" : "petals.action.again")
                    .font(Theme.headlineSerif(20, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Theme.cinnabar, Theme.cinnabarDeep],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.gold.opacity(0.7), lineWidth: 1.5)
            )
            .shadow(color: Theme.cinnabarDeep.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Round logic

    private var defaultYes: String { NSLocalizedString("petals.default.yes", comment: "") }
    private var defaultNo:  String { NSLocalizedString("petals.default.no",  comment: "") }

    private func labelOrDefault(_ s: String, default d: String) -> String {
        s.isEmpty ? d : s
    }

    private var nextLabel: String {
        let yesNext = (pluckCount % 2 == 0) == firstPluckYes
        return yesNext ? labelOrDefault(labelYes, default: defaultYes)
                       : labelOrDefault(labelNo,  default: defaultNo)
    }

    private func startNewRound() {
        questionFocused = false
        firstPluckYes = Bool.random()
        pluckCount = 0
        revealedLabel = nil
        let count = max(3, min(petalCount, 16))
        petals = (0..<count).map { Petal(id: $0, plucked: false, exitTilt: 0, exitOffset: .zero) }
    }

    private func pluck(_ petal: Petal) {
        guard !petal.plucked, revealedLabel == nil else { return }
        guard let idx = petals.firstIndex(where: { $0.id == petal.id }) else { return }
        let remaining = petals.filter { !$0.plucked }.count

        // If this is the LAST petal, that pluck reveals the answer (don't fade it).
        if remaining == 1 {
            revealedLabel = nextLabel
            withAnimation(.easeInOut(duration: 0.5)) {
                // Lift the last petal slightly toward the center as a flourish.
                petals[idx].exitOffset = CGSize(width: 0, height: -10)
            }
            return
        }

        var p = petals[idx]
        p.plucked = true
        p.exitTilt = Double.random(in: -45...45)
        p.exitOffset = CGSize(
            width: CGFloat.random(in: -40...40),
            height: CGFloat.random(in: 60...140)
        )
        withAnimation(.easeOut(duration: 0.55)) {
            petals[idx] = p
        }
        pluckCount += 1
    }
}

// MARK: - Petal shape (long teardrop)

private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        p.move(to: CGPoint(x: cx, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY),
            control1: CGPoint(x: rect.maxX + w * 0.05, y: rect.maxY * 0.55),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.15)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.15),
            control2: CGPoint(x: rect.minX - w * 0.05, y: rect.maxY * 0.55)
        )
        return p
    }
}

// MARK: - Settings sheet

private struct FlowerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var labelYes: String
    @Binding var labelNo: String
    @Binding var petalCount: Int
    var onCommit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("petals.settings.labels") {
                    TextField("petals.default.yes", text: $labelYes)
                    TextField("petals.default.no",  text: $labelNo)
                }
                Section("petals.settings.count") {
                    Stepper(value: $petalCount, in: 5...12) {
                        Text(verbatim: "\(petalCount)")
                            .font(Theme.headlineSerif(18, weight: .semibold))
                            .foregroundStyle(Theme.cinnabarDeep)
                    }
                }
            }
            .navigationTitle("petals.settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") {
                        onCommit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
