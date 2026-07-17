import SwiftUI
import AudioToolbox

/// Two-piece toss — question entry, three user-editable outcome labels
/// (defaults: Yes / Maybe / No), a physical toss animation, and a reveal
/// showing the user's chosen label. Pure random picker — the mechanism
/// assigns no meaning of its own.
struct TwoPieceTossView: View {

    // MARK: - Question

    @AppStorage("twopiece.question") private var question: String = ""
    @FocusState private var questionFocused: Bool

    // MARK: - User-customizable outcome labels

    @AppStorage("twopiece.label.mixed")       private var labelMixed:       String = ""
    @AppStorage("twopiece.label.both_flat")   private var labelBothFlat:    String = ""
    @AppStorage("twopiece.label.both_curved") private var labelBothCurved:  String = ""

    @State private var showingLabelEditor = false

    // MARK: - Toss state

    private enum Phase: Equatable {
        case idle
        case tossing
        case settled(TossOutcome, BlockFace, BlockFace)
    }
    @State private var phase: Phase = .idle

    @State private var leftRotation: Angle = .degrees(-12)
    @State private var rightRotation: Angle = .degrees(14)
    @State private var leftTumble: Angle = .zero
    @State private var rightTumble: Angle = .zero
    @State private var leftOffset: CGSize = .zero
    @State private var rightOffset: CGSize = .zero
    @State private var leftFace: BlockFace = .curved
    @State private var rightFace: BlockFace = .curved
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
                labelMixed: $labelMixed,
                labelBothFlat: $labelBothFlat,
                labelBothCurved: $labelBothCurved
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("twopiece.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)

            TextField("twopiece.question.placeholder", text: $question, axis: .vertical)
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
                    Text("twopiece.labels.title")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(hasCustomLabels ? "twopiece.labels.custom_set" : "twopiece.labels.using_defaults")
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
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    private func revealCard(outcome: TossOutcome) -> some View {
        VStack(spacing: 14) {
            Text(outcome.nameKey)
                .font(Theme.body(13, weight: .semibold))
                .foregroundStyle(Theme.cinnabarDeep)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.gold.opacity(0.22))
                        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1))
                )

            Text(userLabel(for: outcome))
                .font(Theme.headlineSerif(26, weight: .bold))
                .foregroundStyle(Theme.ink)
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

    private var tossButton: some View {
        Button {
            performToss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: phase == .tossing ? "hourglass" : "arrow.triangle.2.circlepath")
                Text(phase == .tossing ? "twopiece.action.tossing" : (isSettled ? "twopiece.action.toss_again" : "twopiece.action.toss"))
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
        !labelMixed.isEmpty || !labelBothFlat.isEmpty || !labelBothCurved.isEmpty
    }

    private func userLabel(for outcome: TossOutcome) -> LocalizedStringKey {
        let custom: String
        switch outcome {
        case .mixed:       custom = labelMixed
        case .bothFlat:    custom = labelBothFlat
        case .bothCurved:  custom = labelBothCurved
        }
        if custom.isEmpty {
            return outcome.defaultUserLabelKey
        }
        return LocalizedStringKey(custom)
    }

    // MARK: - Toss animation

    private func performToss() {
        questionFocused = false

        let faces: [BlockFace] = [.flat, .curved]
        let newLeft  = faces.randomElement()!
        let newRight = faces.randomElement()!
        let outcome = TossOutcome.from(newLeft, newRight)

        withAnimation(.easeIn(duration: 0.15)) {
            revealVisible = false
        }
        phase = .tossing

        leftOffset  = CGSize(width: -10, height: -20)
        rightOffset = CGSize(width:  10, height: -20)
        leftTumble  = .zero
        rightTumble = .zero

        withAnimation(.easeOut(duration: 0.55)) {
            leftOffset  = CGSize(width: -60, height: -110)
            rightOffset = CGSize(width:  60, height: -110)
            leftTumble  = .degrees(Double.random(in: 540...900) * (Bool.random() ? 1 : -1))
            rightTumble = .degrees(Double.random(in: 540...900) * (Bool.random() ? 1 : -1))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
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
    @Binding var labelMixed: String
    @Binding var labelBothFlat: String
    @Binding var labelBothCurved: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    labelField(title: "twopiece.outcome.mixed.name",
                               placeholderKey: "twopiece.outcome.mixed.default_label",
                               text: $labelMixed)
                }
                Section {
                    labelField(title: "twopiece.outcome.both_flat.name",
                               placeholderKey: "twopiece.outcome.both_flat.default_label",
                               text: $labelBothFlat)
                }
                Section {
                    labelField(title: "twopiece.outcome.both_curved.name",
                               placeholderKey: "twopiece.outcome.both_curved.default_label",
                               text: $labelBothCurved)
                }

                Section {
                    Button(role: .destructive) {
                        labelMixed = ""
                        labelBothFlat = ""
                        labelBothCurved = ""
                    } label: {
                        Text("twopiece.labels.reset")
                    }
                }
            }
            .navigationTitle("twopiece.labels.title")
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
