import SwiftUI
import AudioToolbox

struct RandomNumberView: View {

    // MARK: - Per-question state (persists)

    @AppStorage("random.question") private var question: String = ""
    @AppStorage("random.min")      private var minValue: Int = 1
    @AppStorage("random.max")      private var maxValue: Int = 100

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case question, min, max }

    // MARK: - Roll state

    @State private var displayValue: Int = 1
    @State private var revealed: Int?
    @State private var revealVisible: Bool = false
    @State private var spinning: Bool = false
    @State private var spinTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                questionCard
                rangeCard
                stage
                if let final = revealed, revealVisible {
                    revealCard(final: final)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                actionButton
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            if displayValue < minValue || displayValue > maxValue {
                displayValue = max(minValue, 1)
            }
        }
        .onDisappear { spinTask?.cancel() }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("random.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("random.question.placeholder", text: $question, axis: .vertical)
                .font(Theme.headlineSerif(19, weight: .regular))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...3)
                .focused($focusedField, equals: .question)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
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

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("random.range.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 12) {
                rangeField("random.range.min", value: $minValue, focus: .min)
                Text("–")
                    .font(Theme.headlineSerif(20, weight: .semibold))
                    .foregroundStyle(Theme.inkQuiet)
                rangeField("random.range.max", value: $maxValue, focus: .max)
            }

            if !isValidRange {
                Text("random.range.error")
                    .font(Theme.body(12, weight: .medium))
                    .foregroundStyle(Theme.cinnabarDeep)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.parchmentDim.opacity(0.55))
        )
    }

    private func rangeField(_ placeholder: LocalizedStringKey, value: Binding<Int>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeholder)
                .font(Theme.body(11, weight: .semibold))
                .foregroundStyle(Theme.inkQuiet)
                .textCase(.uppercase)
                .tracking(0.5)
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .font(Theme.headlineSerif(22, weight: .semibold))
                .foregroundStyle(Theme.cinnabarDeep)
                .focused($focusedField, equals: focus)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.gold.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity)
    }

    private var stage: some View {
        ZStack {
            // Parchment plaque
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.card, Theme.parchmentDim],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.gold, lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.cinnabar.opacity(0.45), lineWidth: 1)
                        .padding(6)
                )
                .shadow(color: Theme.woodShadow.opacity(0.20), radius: 8, x: 0, y: 4)
                .frame(height: 200)
                .padding(.horizontal, 30)

            Text(verbatim: String(displayValue))
                .font(Theme.headlineSerif(120, weight: .bold))
                .foregroundStyle(Theme.cinnabarDeep)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 50)
                .frame(height: 200)
                // Subtle vertical wobble while spinning so the reel reads as "live".
                .scaleEffect(spinning ? 1.04 : 1.0, anchor: .center)
                .animation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true),
                           value: spinning)
        }
        .frame(height: 220)
    }

    private func revealCard(final: Int) -> some View {
        VStack(spacing: 6) {
            Text("random.reveal.title")
                .font(Theme.body(12, weight: .semibold))
                .foregroundStyle(Theme.inkQuiet)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(verbatim: String(final))
                .font(Theme.headlineSerif(38, weight: .bold))
                .foregroundStyle(Theme.cinnabarDeep)
            Text(String(format: NSLocalizedString("random.range.subtitle", comment: ""),
                        minValue, maxValue))
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
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
        Button { performRoll() } label: {
            HStack(spacing: 10) {
                Image(systemName: spinning ? "hourglass" : "die.face.5")
                Text(spinning
                     ? "random.action.rolling"
                     : (revealed == nil ? "random.action.roll" : "random.action.again"))
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
        .disabled(spinning || !isValidRange)
        .opacity(spinning ? 0.7 : (isValidRange ? 1 : 0.5))
    }

    // MARK: - Validation + roll

    private var isValidRange: Bool {
        minValue > 0 && maxValue > 0 && minValue < maxValue
    }

    private func performRoll() {
        guard isValidRange, !spinning else { return }
        focusedField = nil
        spinTask?.cancel()

        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }
        revealed = nil
        spinning = true

        let target = Int.random(in: minValue...maxValue)
        let lo = minValue
        let hi = maxValue
        let duration: TimeInterval = 0.9
        let tickStart: TimeInterval = 0.04
        let tickEnd: TimeInterval = 0.14   // slow down as we approach the end

        spinTask = Task { @MainActor in
            let startedAt = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed >= duration { break }
                displayValue = Int.random(in: lo...hi)
                // Ease the tick interval from tickStart up to tickEnd.
                let t = elapsed / duration
                let interval = tickStart + (tickEnd - tickStart) * t
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            if Task.isCancelled { return }

            displayValue = target
            revealed = target
            spinning = false
            AudioServicesPlaySystemSound(1104)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                revealVisible = true
            }
        }
    }
}
