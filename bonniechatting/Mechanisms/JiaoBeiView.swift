import SwiftUI
import AudioToolbox

/// The full 筊杯 experience: question entry → optional outcome labels → toss → reveal.
struct JiaoBeiView: View {

    // MARK: - Question

    @State private var question: String = ""
    @FocusState private var questionFocused: Bool

    // MARK: - User-customized outcome labels (persist between sessions)

    @AppStorage("jiaobei.label.sheng") private var labelSheng: String = ""
    @AppStorage("jiaobei.label.xiao")  private var labelXiao:  String = ""
    @AppStorage("jiaobei.label.yin")   private var labelYin:   String = ""

    @State private var showingLabelEditor = false

    // MARK: - Toss state

    /// Toss phase drives the animation + reveal.
    private enum Phase: Equatable {
        case idle
        case tossing
        case settled(JiaoBeiOutcome, BlockFace, BlockFace)
    }
    @State private var phase: Phase = .idle

    /// Per-block visual state. Re-driven on each toss.
    @State private var leftRotation: Angle = .degrees(-12)
    @State private var rightRotation: Angle = .degrees(14)
    @State private var leftTumble: Angle = .zero
    @State private var rightTumble: Angle = .zero
    @State private var leftOffset: CGSize = .zero
    @State private var rightOffset: CGSize = .zero
    @State private var leftFace: BlockFace = .flat
    @State private var rightFace: BlockFace = .flat
    @State private var revealVisible: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                questionCard
                outcomeLabelsCard
                stage
                if case let .settled(outcome, _, _) = phase, revealVisible {
                    revealCard(outcome: outcome)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                tossButton
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.immediately)
        .parchmentBackground()
        .sheet(isPresented: $showingLabelEditor) {
            OutcomeLabelEditor(
                labelSheng: $labelSheng,
                labelXiao: $labelXiao,
                labelYin: $labelYin
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("jiaobei.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)

            TextField("jiaobei.question.placeholder", text: $question, axis: .vertical)
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
                .shadow(color: Theme.woodShadow.opacity(0.10), radius: 4, x: 0, y: 2)
        )
    }

    private var outcomeLabelsCard: some View {
        Button {
            showingLabelEditor = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("jiaobei.labels.title")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(hasCustomLabels ? "jiaobei.labels.custom_set" : "jiaobei.labels.using_defaults")
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

    private var stage: some View {
        ZStack {
            // The "ground": a soft golden disc the blocks sit on.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.35), Theme.parchment.opacity(0)],
                        center: .center,
                        startRadius: 30,
                        endRadius: 200
                    )
                )
                .frame(height: 240)

            if phase == .idle {
                idleComposition
            } else {
                tossedComposition
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    /// Before any toss: the two blocks rest touching at their flat edges,
    /// forming a complete circle with a thin dark hairline at the seam.
    /// The tap-to-toss animation will split them apart.
    private var idleComposition: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left block: rotated CCW so the flat edge faces the seam
                // (right side of the left block); dome wraps around outside.
                MoonBlockView(face: .flat)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 75, height: 150)
                // Right block: rotated CW so the flat edge faces the seam
                // (left side of the right block); dome wraps around outside.
                MoonBlockView(face: .flat)
                    .rotationEffect(.degrees(90))
                    .frame(width: 75, height: 150)
            }
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 1, height: 148)
        }
    }

    /// During and after the toss: independent blocks with their own
    /// rotations and offsets driven by `performToss`.
    private var tossedComposition: some View {
        HStack(spacing: 24) {
            MoonBlockView(
                face: leftFace,
                rotation: leftRotation,
                tumble: leftTumble,
                translation: leftOffset
            )
            MoonBlockView(
                face: rightFace,
                rotation: rightRotation,
                tumble: rightTumble,
                translation: rightOffset
            )
        }
    }

    private func revealCard(outcome: JiaoBeiOutcome) -> some View {
        VStack(spacing: 14) {
            // Chinese name pill
            Text(outcome.nameKey)
                .font(Theme.headlineSerif(28, weight: .bold))
                .foregroundStyle(Theme.cinnabarDeep)
                .padding(.horizontal, 22)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.gold.opacity(0.25))
                        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1))
                )

            // User-facing answer (custom if set, otherwise the default)
            Text(userLabel(for: outcome))
                .font(Theme.headlineSerif(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            // Traditional meaning
            Text(outcome.descriptionKey)
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
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

    private var tossButton: some View {
        Button {
            performToss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: phase == .tossing ? "hourglass" : "sparkles")
                Text(phase == .tossing ? "jiaobei.action.tossing" : (isSettled ? "jiaobei.action.toss_again" : "jiaobei.action.toss"))
                    .font(Theme.headlineSerif(20, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Theme.cinnabar, Theme.cinnabarDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.gold.opacity(0.7), lineWidth: 1.5)
            )
            .shadow(color: Theme.cinnabarDeep.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(phase == .tossing)
        .opacity(phase == .tossing ? 0.7 : 1)
    }

    // MARK: - Helpers

    private var isSettled: Bool {
        if case .settled = phase { return true }
        return false
    }

    private var hasCustomLabels: Bool {
        !labelSheng.isEmpty || !labelXiao.isEmpty || !labelYin.isEmpty
    }

    private func userLabel(for outcome: JiaoBeiOutcome) -> LocalizedStringKey {
        let custom: String
        switch outcome {
        case .sheng: custom = labelSheng
        case .xiao:  custom = labelXiao
        case .yin:   custom = labelYin
        }
        if custom.isEmpty {
            return outcome.defaultUserLabelKey
        }
        return LocalizedStringKey(custom)
    }

    // MARK: - Toss animation

    private func performToss() {
        questionFocused = false

        // Randomize the outcome.
        let faces: [BlockFace] = [.flat, .curved]
        let newLeft  = faces.randomElement()!
        let newRight = faces.randomElement()!
        let outcome = JiaoBeiOutcome.from(newLeft, newRight)

        // Hide the previous reveal first.
        withAnimation(.easeIn(duration: 0.15)) {
            revealVisible = false
        }
        phase = .tossing

        // Reset to a small "pickup" pose, then fling.
        leftOffset  = CGSize(width: -10, height: -20)
        rightOffset = CGSize(width:  10, height: -20)
        leftTumble  = .zero
        rightTumble = .zero

        // Phase 1: high arc — blocks travel up and tumble fast.
        withAnimation(.easeOut(duration: 0.55)) {
            leftOffset  = CGSize(width: -60, height: -110)
            rightOffset = CGSize(width:  60, height: -110)
            leftTumble  = .degrees(Double.random(in: 540...900) * (Bool.random() ? 1 : -1))
            rightTumble = .degrees(Double.random(in: 540...900) * (Bool.random() ? 1 : -1))
        }

        // Phase 2: fall and settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            // Lock in the final faces just before they land.
            leftFace  = newLeft
            rightFace = newRight

            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                leftOffset  = CGSize(width: -10, height: 12)
                rightOffset = CGSize(width:  10, height: 12)
                leftRotation  = .degrees(Double.random(in: -28...28))
                rightRotation = .degrees(Double.random(in: -28...28))
                leftTumble  = .zero
                rightTumble = .zero
            }

            // Wooden "clack" — a built-in sound that is close enough to a knock.
            // 1104 = "Tock" on iOS. Soft, satisfying.
            AudioServicesPlaySystemSound(1104)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                phase = .settled(outcome, newLeft, newRight)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    revealVisible = true
                }
            }
        }
    }
}

// MARK: - Outcome label editor sheet

private struct OutcomeLabelEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var labelSheng: String
    @Binding var labelXiao: String
    @Binding var labelYin: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    labelField(title: "jiaobei.outcome.sheng.name",
                               placeholderKey: "jiaobei.outcome.sheng.default_label",
                               text: $labelSheng)
                } footer: {
                    Text("jiaobei.outcome.sheng.desc")
                }
                Section {
                    labelField(title: "jiaobei.outcome.xiao.name",
                               placeholderKey: "jiaobei.outcome.xiao.default_label",
                               text: $labelXiao)
                } footer: {
                    Text("jiaobei.outcome.xiao.desc")
                }
                Section {
                    labelField(title: "jiaobei.outcome.yin.name",
                               placeholderKey: "jiaobei.outcome.yin.default_label",
                               text: $labelYin)
                } footer: {
                    Text("jiaobei.outcome.yin.desc")
                }

                Section {
                    Button(role: .destructive) {
                        labelSheng = ""
                        labelXiao = ""
                        labelYin = ""
                    } label: {
                        Text("jiaobei.labels.reset")
                    }
                }
            }
            .navigationTitle("jiaobei.labels.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func labelField(title: LocalizedStringKey, placeholderKey: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.headlineSerif(17, weight: .semibold))
                .foregroundStyle(Theme.cinnabarDeep)
            TextField(placeholderKey, text: text, axis: .vertical)
                .lineLimit(1...3)
        }
        .padding(.vertical, 4)
    }
}
