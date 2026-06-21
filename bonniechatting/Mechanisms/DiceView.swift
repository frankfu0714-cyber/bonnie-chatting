import SwiftUI
import AudioToolbox

struct DiceView: View {

    // MARK: - Per-question state (persists)

    @AppStorage("dice.question")  private var question: String = ""
    @AppStorage("dice.count")     private var diceCount: Int = 2

    @Environment(\.locale) private var locale
    @FocusState private var questionFocused: Bool

    // MARK: - Roll state

    /// Final values for each die (1–6). Empty before any roll.
    @State private var results: [Int] = []
    /// Per-die value shown — scrambles during tumble, locks at impact.
    @State private var displayValues: [Int] = []
    /// Per-die vertical offset for the drop + bounce.
    @State private var verticalOffset: [CGFloat] = []
    /// Per-die post-settle 2D rotation wobble in degrees.
    @State private var wobble: [Double] = []
    /// Per-die locked flag — once true, displayValues[i] is the final face.
    @State private var locked: [Bool] = []

    @State private var rolling: Bool = false
    @State private var revealVisible: Bool = false
    @State private var scrambleTimer: Timer?
    /// Identity of the in-flight roll — stale scheduled work checks against
    /// this to no-op if a new roll has started.
    @State private var rollID: UUID = UUID()

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
        .onDisappear { stopScramble() }
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.25), Theme.parchment.opacity(0)],
                        center: .center, startRadius: 40, endRadius: 220
                    )
                )
                .frame(height: 220)
                .padding(.horizontal, 8)

            VStack(spacing: 14) {
                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    HStack(spacing: 14) {
                        ForEach(rows[rowIdx], id: \.self) { slot in
                            DieView(
                                face: faceFor(slot),
                                verticalOffset: verticalOffset.indices.contains(slot) ? verticalOffset[slot] : 0,
                                wobble: wobble.indices.contains(slot) ? wobble[slot] : 0
                            )
                        }
                    }
                }
            }
        }
        .frame(height: 240)
        .clipped()
    }

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
        if displayValues.indices.contains(slot) {
            return displayValues[slot]
        }
        if results.indices.contains(slot) {
            return results[slot]
        }
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
                Text(String(format: String.appLocalized("dice.reveal.sum", locale: locale), results.reduce(0, +)))
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
        if displayValues.count != n  { displayValues  = Array(repeating: 1, count: n) }
        if verticalOffset.count != n { verticalOffset = Array(repeating: 0, count: n) }
        if wobble.count != n         { wobble         = Array(repeating: 0, count: n) }
        if locked.count != n         { locked         = Array(repeating: true, count: n) }
    }

    private func performRoll() {
        guard !rolling else { return }
        questionFocused = false
        stopScramble()
        ensureSlots()

        let n = max(1, min(6, diceCount))
        let target = (0..<n).map { _ in Int.random(in: 1...6) }

        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }
        results = []
        rolling = true
        rollID = UUID()
        let myRoll = rollID

        // Reset visuals: dice lifted above the stage, ready to drop.
        var newOffsets = Array(repeating: CGFloat(0), count: n)
        var newLocked  = Array(repeating: false, count: n)
        for i in 0..<n {
            newOffsets[i] = -CGFloat.random(in: 110...150)
        }
        withTransaction(Transaction(animation: nil)) {
            verticalOffset = newOffsets
            wobble = Array(repeating: 0, count: n)
            displayValues = (0..<n).map { _ in Int.random(in: 1...6) }
            locked = newLocked
        }

        // Start scrambling the visible face on un-locked dice. The face
        // flicker is what reads as "tumbling" — no 3D rotation involved,
        // so the dice stay perfectly square the whole time.
        startScramble(myRoll: myRoll)

        // Per-die stagger + drop + bounce + settle wobble. All motion is 2D
        // (vertical offset + z-axis 2D rotation), no perspective effects.
        for i in 0..<n {
            let spawnDelay = Double(i) * 0.07 + Double.random(in: 0...0.04)
            let speed = Double.random(in: 0.88...1.18)
            let drop   = 0.32 * speed
            let bUp    = 0.10 * speed
            let bDown  = 0.13 * speed

            // Phase 1: drop — easeIn for gravity-like acceleration.
            DispatchQueue.main.asyncAfter(deadline: .now() + spawnDelay) {
                guard rollID == myRoll else { return }
                withAnimation(.easeIn(duration: drop)) {
                    verticalOffset[i] = 0
                }
            }

            // Phase 2: impact + bounce up. Play clack at impact time.
            DispatchQueue.main.asyncAfter(deadline: .now() + spawnDelay + drop) {
                guard rollID == myRoll else { return }
                AudioServicesPlaySystemSound(1104)
                withAnimation(.easeOut(duration: bUp)) {
                    verticalOffset[i] = -CGFloat.random(in: 10...18)
                }
            }

            // Phase 3: settle down from bounce.
            DispatchQueue.main.asyncAfter(deadline: .now() + spawnDelay + drop + bUp) {
                guard rollID == myRoll else { return }
                withAnimation(.easeIn(duration: bDown)) {
                    verticalOffset[i] = 0
                }
            }

            // Phase 4: lock in the final face + tiny 2D wobble for weight.
            let lockAt = spawnDelay + drop + bUp + bDown
            DispatchQueue.main.asyncAfter(deadline: .now() + lockAt) {
                guard rollID == myRoll else { return }
                displayValues[i] = target[i]
                locked[i] = true
                let wobbleAmt = Double.random(in: 2.0...3.5) * (Bool.random() ? 1 : -1)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                    wobble[i] = wobbleAmt
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + lockAt + 0.14) {
                guard rollID == myRoll else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    wobble[i] = 0
                }
            }
        }

        // After the last die settles, fire the reveal card.
        let lastEnd = Double(n - 1) * 0.07 + 0.04 + 0.38 + 0.12 + 0.16 + 0.18
        DispatchQueue.main.asyncAfter(deadline: .now() + lastEnd) {
            guard rollID == myRoll else { return }
            stopScramble()
            results = target
            displayValues = target
            rolling = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                revealVisible = true
            }
        }
    }

    // MARK: - Scramble timer

    /// While the roll is in flight, scramble the visible face of any die
    /// that has NOT yet been locked. Locked dice show their final value.
    private func startScramble(myRoll: UUID) {
        scrambleTimer?.invalidate()
        scrambleTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { t in
            guard rollID == myRoll else {
                t.invalidate()
                return
            }
            for i in displayValues.indices {
                if locked.indices.contains(i), !locked[i] {
                    displayValues[i] = Int.random(in: 1...6)
                }
            }
        }
    }

    private func stopScramble() {
        scrambleTimer?.invalidate()
        scrambleTimer = nil
    }
}

// MARK: - Die rendering

/// One die: rounded white square with rapidly-cycling pips during the toss
/// plus a 2D vertical drop and a tiny 2D settle wobble. NO `rotation3DEffect`
/// — the cube stays a perfectly undistorted square the entire time. The
/// "tumbling" feel comes from face flicker (see `startScramble`).
private struct DieView: View {
    let face: Int
    let verticalOffset: CGFloat
    let wobble: Double

    private let dieSize: CGFloat = 58

    var body: some View {
        ZStack {
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
        .rotationEffect(.degrees(wobble))
        .offset(y: verticalOffset)
    }
}

/// Black pips laid out for a given face value.
private struct PipsView: View {
    let face: Int

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
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

