import SwiftUI
import AudioToolbox

struct DiceView: View {

    // MARK: - Per-question state (persists)

    @AppStorage("dice.question")  private var question: String = ""
    @AppStorage("dice.count")     private var diceCount: Int = 2

    @FocusState private var questionFocused: Bool

    // MARK: - Roll state

    /// Final values for each die (1–6). Empty before any roll.
    @State private var results: [Int] = []
    /// Per-die value shown during the tumble — scrambles every tick.
    @State private var displayValues: [Int] = []
    /// Per-die tumble rotations (random axes).
    @State private var tumble: [DieTumble] = []
    @State private var rolling: Bool = false
    @State private var revealVisible: Bool = false
    @State private var rollTimer: Timer?
    @State private var rollStartedAt: Date?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                questionCard
                countCard
                stage
                if !results.isEmpty, revealVisible {
                    revealCard
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                actionButton
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear { ensureSlots() }
        .onDisappear { stopRoll() }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dice.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("dice.question.placeholder", text: $question, axis: .vertical)
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

    private var countCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("dice.count.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 8) {
                ForEach(1...6, id: \.self) { n in
                    countChip(n)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.parchmentDim.opacity(0.55))
        )
    }

    @ViewBuilder
    private func countChip(_ n: Int) -> some View {
        let selected = (diceCount == n)
        Button {
            guard !rolling else { return }
            diceCount = n
            ensureSlots()
            // Clear any prior reveal — count change means previous results no
            // longer correspond to what the user sees on stage.
            if !results.isEmpty {
                withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }
                results = []
            }
        } label: {
            Text(verbatim: String(n))
                .font(Theme.headlineSerif(18, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Theme.cinnabarDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Theme.cinnabar : Theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Theme.gold : Theme.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(rolling)
    }

    private var stage: some View {
        ZStack {
            // Felt-style table beneath the dice.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.25), Theme.parchment.opacity(0)],
                        center: .center, startRadius: 40, endRadius: 220
                    )
                )
                .frame(height: 220)
                .padding(.horizontal, 8)

            // Dice grid: 1-3 in one row, 4-6 wrap to two rows.
            VStack(spacing: 14) {
                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    HStack(spacing: 14) {
                        ForEach(rows[rowIdx], id: \.self) { slot in
                            DieView(
                                face: faceFor(slot),
                                tumble: tumble.indices.contains(slot) ? tumble[slot] : .zero
                            )
                        }
                    }
                }
            }
        }
        .frame(height: 240)
    }

    /// Lay out the dice in 1–2 rows: up to 3 per row, second row balances.
    private var rows: [[Int]] {
        let total = max(1, min(6, diceCount))
        let perRow = total <= 3 ? total : Int(ceil(Double(total) / 2.0))
        var out: [[Int]] = []
        var idx = 0
        while idx < total {
            let end = min(total, idx + perRow)
            out.append(Array(idx..<end))
            idx = end
        }
        return out
    }

    private func faceFor(_ slot: Int) -> Int {
        if rolling, displayValues.indices.contains(slot) {
            return displayValues[slot]
        }
        if results.indices.contains(slot) {
            return results[slot]
        }
        // Pre-roll placeholder: a calm "1".
        return 1
    }

    private var revealCard: some View {
        VStack(spacing: 12) {
            Text("dice.reveal.title")
                .font(Theme.body(12, weight: .semibold))
                .foregroundStyle(Theme.inkQuiet)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 10) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, v in
                    Text(verbatim: String(v))
                        .font(Theme.headlineSerif(24, weight: .bold))
                        .foregroundStyle(Theme.cinnabarDeep)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(
                            Circle()
                                .fill(Theme.gold.opacity(0.22))
                                .overlay(Circle().stroke(Theme.gold, lineWidth: 1))
                        )
                }
            }

            if results.count > 1 {
                Text(String(format: NSLocalizedString("dice.reveal.sum", comment: ""), results.reduce(0, +)))
                    .font(Theme.headlineSerif(20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
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
                Image(systemName: rolling ? "hourglass" : "die.face.5.fill")
                Text(rolling
                     ? "dice.action.rolling"
                     : (results.isEmpty ? "dice.action.roll" : "dice.action.again"))
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
        .disabled(rolling)
        .opacity(rolling ? 0.7 : 1)
    }

    // MARK: - Roll

    private func ensureSlots() {
        let n = max(1, min(6, diceCount))
        if displayValues.count != n {
            displayValues = Array(repeating: 1, count: n)
        }
        if tumble.count != n {
            tumble = Array(repeating: .zero, count: n)
        }
    }

    private func performRoll() {
        guard !rolling else { return }
        questionFocused = false
        stopRoll()
        ensureSlots()

        let n = max(1, min(6, diceCount))
        let finalResults = (0..<n).map { _ in Int.random(in: 1...6) }

        // Hide the previous reveal first.
        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }
        results = []
        rolling = true

        // Kick off random 3-axis rotations per die.
        let newTumbles: [DieTumble] = (0..<n).map { _ in DieTumble.random() }
        withAnimation(.easeOut(duration: 1.0)) {
            tumble = newTumbles
        }

        rollStartedAt = Date()
        scheduleNextScrambleTick(target: finalResults, duration: 1.15)
    }

    /// Tick: scramble each die's visible face. As we near the end, the tick
    /// rate slows so it visibly "settles."
    private func scheduleNextScrambleTick(target: [Int], duration: TimeInterval) {
        guard let started = rollStartedAt else { return }
        rollTimer?.invalidate()

        let elapsed = Date().timeIntervalSince(started)
        let t = min(1.0, elapsed / duration)
        let delay = 0.06 + (0.18 - 0.06) * t

        rollTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            guard rollStartedAt == started else { return }

            let now = Date().timeIntervalSince(started)
            if now >= duration {
                // Settle: lock in faces, neutralize tumble so the dice sit flat.
                stopRoll()
                results = target
                displayValues = target
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    tumble = Array(repeating: .zero, count: target.count)
                }
                rolling = false
                AudioServicesPlaySystemSound(1104) // "Tock"
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    revealVisible = true
                }
                return
            }

            displayValues = displayValues.indices.map { _ in Int.random(in: 1...6) }
            scheduleNextScrambleTick(target: target, duration: duration)
        }
    }

    private func stopRoll() {
        rollTimer?.invalidate()
        rollTimer = nil
        rollStartedAt = nil
    }
}

// MARK: - Die rendering

/// One die: rounded white square with a slight 3D tilt and black pips.
private struct DieView: View {
    let face: Int
    let tumble: DieTumble

    private let dieSize: CGFloat = 58

    var body: some View {
        ZStack {
            // Top-edge highlight stripe — applied behind the face to suggest
            // light hitting the top bevel.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(white: 0.86)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(white: 0.55), lineWidth: 0.8)
                )
                .frame(width: dieSize, height: dieSize)

            PipsView(face: face)
                .frame(width: dieSize, height: dieSize)
                .padding(10)
        }
        .frame(width: dieSize, height: dieSize)
        .shadow(color: Theme.woodShadow.opacity(0.35), radius: 4, x: 1, y: 3)
        .rotation3DEffect(.degrees(tumble.x), axis: (1, 0, 0))
        .rotation3DEffect(.degrees(tumble.y), axis: (0, 1, 0))
        .rotation3DEffect(.degrees(tumble.z), axis: (0, 0, 1))
    }
}

/// Black pips laid out for a given face value.
private struct PipsView: View {
    let face: Int

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            // Three-column grid positions, centred. Pip diameter scales with die.
            let pipD = s * 0.18
            ZStack {
                ForEach(0..<pipsFor(face: face).count, id: \.self) { i in
                    Circle()
                        .fill(Color.black)
                        .frame(width: pipD, height: pipD)
                        .position(
                            x: geo.size.width / 2 + pipsFor(face: face)[i].x * s * 0.32,
                            y: geo.size.height / 2 + pipsFor(face: face)[i].y * s * 0.32
                        )
                }
            }
        }
    }

    /// Unit-vector pip positions (-1, 0, +1) around the centre.
    private func pipsFor(face: Int) -> [CGPoint] {
        switch face {
        case 1:
            return [CGPoint(x: 0, y: 0)]
        case 2:
            return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: 1)]
        case 3:
            return [CGPoint(x: -1, y: -1), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        case 4:
            return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1),
                    CGPoint(x: -1, y: 1),  CGPoint(x: 1, y: 1)]
        case 5:
            return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1),
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: -1, y: 1),  CGPoint(x: 1, y: 1)]
        case 6:
            return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1),
                    CGPoint(x: -1, y: 0),  CGPoint(x: 1, y: 0),
                    CGPoint(x: -1, y: 1),  CGPoint(x: 1, y: 1)]
        default:
            return []
        }
    }
}

/// Random 3-axis rotation for a single die.
private struct DieTumble: Equatable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = DieTumble(x: 0, y: 0, z: 0)

    static func random() -> DieTumble {
        DieTumble(
            x: Double.random(in: 180...720) * (Bool.random() ? 1 : -1),
            y: Double.random(in: 180...720) * (Bool.random() ? 1 : -1),
            z: Double.random(in: -40...40)
        )
    }
}
