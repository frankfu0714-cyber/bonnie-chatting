import SwiftUI
import AudioToolbox

/// The full Magic 8-Ball experience: question entry → optional outcome labels
/// → shake → reveal.
struct MagicEightBallView: View {

    // MARK: - Question

    @State private var question: String = ""
    @FocusState private var questionFocused: Bool

    // MARK: - User-customized outcome labels (persist between sessions)

    @AppStorage("magic8ball.label.yes")   private var labelYes:   String = ""
    @AppStorage("magic8ball.label.maybe") private var labelMaybe: String = ""
    @AppStorage("magic8ball.label.no")    private var labelNo:    String = ""

    @State private var showingLabelEditor = false

    // MARK: - Shake state

    private enum Phase: Equatable {
        case idle
        case shaking
        case settled(EightBallOutcome)
    }
    @State private var phase: Phase = .idle

    @State private var ballOffset: CGSize = .zero
    @State private var ballRotation: Angle = .zero
    @State private var windowOpacity: Double = 1.0
    @State private var currentOutcome: EightBallOutcome = .maybe
    @State private var revealVisible: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                questionCard
                outcomeLabelsCard
                stage
                if case let .settled(outcome) = phase, revealVisible {
                    revealCard(outcome: outcome)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                shakeButton
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.immediately)
        .parchmentBackground()
        .sheet(isPresented: $showingLabelEditor) {
            EightBallLabelEditor(
                labelYes: $labelYes,
                labelMaybe: $labelMaybe,
                labelNo: $labelNo
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("magic8ball.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)

            TextField("magic8ball.question.placeholder", text: $question, axis: .vertical)
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
                    Text("magic8ball.labels.title")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(hasCustomLabels ? "magic8ball.labels.custom_set" : "magic8ball.labels.using_defaults")
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
            // Ground glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.25), Theme.parchment.opacity(0)],
                        center: .center,
                        startRadius: 30,
                        endRadius: 200
                    )
                )
                .frame(height: 260)

            EightBallShape(outcomeText: outcomeText, windowOpacity: windowOpacity)
                .offset(ballOffset)
                .rotationEffect(ballRotation)
        }
        .frame(height: 240)
        .padding(.vertical, 8)
    }

    private var outcomeText: LocalizedStringKey {
        switch phase {
        case .idle:
            return "magic8ball.window.idle"
        case .shaking:
            return "magic8ball.window.shaking"
        case .settled(let o):
            return userLabel(for: o)
        }
    }

    private func revealCard(outcome: EightBallOutcome) -> some View {
        VStack(spacing: 12) {
            Text(outcome.titleKey)
                .font(Theme.headlineSerif(24, weight: .bold))
                .foregroundStyle(Theme.cinnabarDeep)
                .padding(.horizontal, 22)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.gold.opacity(0.25))
                        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1))
                )

            Text(userLabel(for: outcome))
                .font(Theme.headlineSerif(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

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

    private var shakeButton: some View {
        Button {
            performShake()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: phase == .shaking ? "hourglass" : "sparkles")
                Text(phase == .shaking
                     ? "magic8ball.action.shaking"
                     : (isSettled ? "magic8ball.action.again" : "magic8ball.action.shake"))
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
        .disabled(phase == .shaking)
        .opacity(phase == .shaking ? 0.7 : 1)
    }

    // MARK: - Helpers

    private var isSettled: Bool {
        if case .settled = phase { return true }
        return false
    }

    private var hasCustomLabels: Bool {
        !labelYes.isEmpty || !labelMaybe.isEmpty || !labelNo.isEmpty
    }

    private func userLabel(for outcome: EightBallOutcome) -> LocalizedStringKey {
        let custom: String
        switch outcome {
        case .yes:   custom = labelYes
        case .maybe: custom = labelMaybe
        case .no:    custom = labelNo
        }
        if custom.isEmpty {
            return outcome.defaultUserLabelKey
        }
        return LocalizedStringKey(custom)
    }

    // MARK: - Shake animation

    private func performShake() {
        questionFocused = false
        let outcome = EightBallOutcome.allCases.randomElement()!

        withAnimation(.easeIn(duration: 0.15)) {
            revealVisible = false
            windowOpacity = 0
        }
        phase = .shaking

        // Shake — quick left/right jitter.
        let shakeDuration = 0.7
        withAnimation(.easeInOut(duration: shakeDuration / 8).repeatCount(8, autoreverses: true)) {
            ballOffset = CGSize(width: 14, height: -6)
            ballRotation = .degrees(10)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                ballOffset = .zero
                ballRotation = .zero
            }

            // Soft "tock" — mirrors the felt weight from the moon-block feel.
            AudioServicesPlaySystemSound(1104)

            currentOutcome = outcome
            phase = .settled(outcome)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.35)) {
                    windowOpacity = 1
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    revealVisible = true
                }
            }
        }
    }
}

// MARK: - Ball visual

private struct EightBallShape: View {
    let outcomeText: LocalizedStringKey
    let windowOpacity: Double

    var body: some View {
        ZStack {
            // Body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.28), Color(white: 0.08)],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 4,
                        endRadius: 180
                    )
                )
                .frame(width: 220, height: 220)
                .overlay(
                    // Subtle highlight arc top-left
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 210, height: 210)
                        .blur(radius: 1.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 8)

            // White "8" disc — upper portion
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 74, height: 74)
                Text("8")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
            }
            .offset(y: -32)

            // Triangular reveal window — lower portion
            ZStack {
                Triangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.12, blue: 0.42),
                                     Color(red: 0.03, green: 0.05, blue: 0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 118, height: 100)
                    .overlay(
                        Triangle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            .frame(width: 118, height: 100)
                    )
                Text(outcomeText)
                    .font(Theme.body(12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 10)
                    .padding(.top, 26)
                    .frame(width: 118, height: 100)
                    .opacity(windowOpacity)
            }
            .offset(y: 40)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Outcome label editor sheet

private struct EightBallLabelEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var labelYes: String
    @Binding var labelMaybe: String
    @Binding var labelNo: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    labelField(title: "magic8ball.outcome.yes.title",
                               placeholderKey: "magic8ball.outcome.yes.default_label",
                               text: $labelYes)
                } footer: {
                    Text("magic8ball.outcome.yes.desc")
                }
                Section {
                    labelField(title: "magic8ball.outcome.maybe.title",
                               placeholderKey: "magic8ball.outcome.maybe.default_label",
                               text: $labelMaybe)
                } footer: {
                    Text("magic8ball.outcome.maybe.desc")
                }
                Section {
                    labelField(title: "magic8ball.outcome.no.title",
                               placeholderKey: "magic8ball.outcome.no.default_label",
                               text: $labelNo)
                } footer: {
                    Text("magic8ball.outcome.no.desc")
                }

                Section {
                    Button(role: .destructive) {
                        labelYes = ""
                        labelMaybe = ""
                        labelNo = ""
                    } label: {
                        Text("magic8ball.labels.reset")
                    }
                }
            }
            .navigationTitle("magic8ball.labels.title")
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
