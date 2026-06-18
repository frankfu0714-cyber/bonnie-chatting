import SwiftUI

struct TissueView: View {

    // MARK: - Per-question state (persists across launches)

    @AppStorage("tissues.question") private var question: String = ""
    @AppStorage("tissues.labelYes") private var labelYes: String = ""
    @AppStorage("tissues.labelNo")  private var labelNo: String = ""

    @FocusState private var questionFocused: Bool
    @State private var showingSettings = false

    // MARK: - Round state (transient, fresh each round)

    /// Total tissues this round — randomized between 10 and 20 so the user
    /// can't infer the final answer from parity.
    @State private var totalCount: Int = 0
    @State private var remaining: Int = 0
    @State private var pluckCount: Int = 0
    /// Whether the *first* pull registers as "yes". Randomized each round.
    @State private var firstPluckYes: Bool = true
    @State private var revealedLabel: String?

    // MARK: - Animation state

    private enum Phase: Equatable { case idle, pulling }
    @State private var phase: Phase = .idle
    @State private var tissueOffsetY: CGFloat = 0
    @State private var tissueRotation: Double = 0
    @State private var tissueOpacity: Double = 1
    /// True only for the final tissue — lifted with a soft glow as the reveal.
    @State private var finalLift: Bool = false

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
        .onAppear { if totalCount == 0 { startNewRound() } }
        .sheet(isPresented: $showingSettings) {
            TissueSettingsSheet(labelYes: $labelYes, labelNo: $labelNo)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tissues.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("tissues.question.placeholder", text: $question, axis: .vertical)
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
        Button { showingSettings = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("tissues.labels.title")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 6) {
                        Text(labelOrDefault(labelYes, default: defaultYes))
                            .font(Theme.body(12, weight: .semibold))
                            .foregroundStyle(Theme.cinnabarDeep)
                        Text("／")
                            .foregroundStyle(Theme.inkQuiet)
                        Text(labelOrDefault(labelNo, default: defaultNo))
                            .font(Theme.body(12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
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
            // Glow under the box
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.30), Theme.parchment.opacity(0)],
                        center: .center, startRadius: 30, endRadius: 220
                    )
                )
                .frame(width: 360, height: 240)
                .offset(y: 30)

            // Tissue box + popping tissue.
            ZStack {
                TissueBoxShape()
                    .frame(width: 240, height: 150)
                    .offset(y: 50)

                // Glow halo for the final tissue.
                if finalLift {
                    Capsule()
                        .fill(Theme.gold.opacity(0.55))
                        .frame(width: 150, height: 110)
                        .blur(radius: 22)
                        .offset(y: -30 + tissueOffsetY)
                }

                // The tissue itself — wrapped in a Button for reliable hit
                // testing inside the ScrollView.
                Button {
                    performPull()
                } label: {
                    TissueShape()
                        .frame(width: 130, height: 96)
                        .rotationEffect(.degrees(tissueRotation))
                        .opacity(tissueOpacity)
                        .frame(width: 170, height: 130)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: -20 + tissueOffsetY)
                .allowsHitTesting(phase == .idle && revealedLabel == nil)
            }
            .frame(height: 260)

            // Bottom-center: "X left" + alternation hint.
            VStack {
                Spacer()
                if revealedLabel == nil {
                    HStack(spacing: 10) {
                        countPill
                        nextHintPill
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(height: 320)
    }

    private var countPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(verbatim: String(remaining))
                .font(Theme.body(12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.parchmentDim.opacity(0.7)))
        .overlay(Capsule().stroke(Theme.rule, lineWidth: 0.8))
        .foregroundStyle(Theme.inkSoft)
    }

    private var nextHintPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap")
                .font(.system(size: 12, weight: .semibold))
            Text("tissues.next_hint")
                .font(Theme.body(12, weight: .semibold))
            Text("→")
            Text(nextLabel)
                .font(Theme.headlineSerif(14, weight: .semibold))
                .foregroundStyle(Theme.cinnabarDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.card.opacity(0.92)))
        .overlay(Capsule().stroke(Theme.gold.opacity(0.55), lineWidth: 0.8))
        .foregroundStyle(Theme.inkSoft)
    }

    private func revealCard(label: String) -> some View {
        VStack(spacing: 10) {
            Text("tissues.reveal.title")
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
        Button { startNewRound() } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                Text(revealedLabel == nil ? "tissues.action.fresh" : "tissues.action.again")
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

    private var defaultYes: String { NSLocalizedString("tissues.default.yes", comment: "") }
    private var defaultNo:  String { NSLocalizedString("tissues.default.no",  comment: "") }

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
        totalCount = Int.random(in: 10...20)
        remaining = totalCount
        phase = .idle
        finalLift = false
        tissueOffsetY = 0
        tissueRotation = 0
        tissueOpacity = 1
    }

    private func performPull() {
        guard phase == .idle, revealedLabel == nil, remaining > 0 else { return }

        // Final pull — don't fade the tissue, lift it with a glow and reveal.
        if remaining == 1 {
            let label = nextLabel
            revealedLabel = label
            withAnimation(.easeOut(duration: 0.6)) {
                finalLift = true
                tissueOffsetY = -45
            }
            return
        }

        phase = .pulling
        let exitTilt = Double.random(in: -22...22)

        // Phase 1: tissue slides up out of the slot and fades.
        withAnimation(.easeOut(duration: 0.42)) {
            tissueOffsetY = -180
            tissueRotation = exitTilt
            tissueOpacity = 0
        }

        // Phase 2: after a beat, snap a fresh tissue back into position
        // (invisible during the snap) and fade it in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            remaining -= 1
            pluckCount += 1
            tissueOffsetY = 12         // start slightly below the slot
            tissueRotation = 0
            tissueOpacity = 0
            withAnimation(.easeOut(duration: 0.28)) {
                tissueOffsetY = 0
                tissueOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                phase = .idle
            }
        }
    }
}

// MARK: - Tissue-box shape

private struct TissueBoxShape: View {
    var body: some View {
        ZStack {
            // Box body — parchment with a soft gradient.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.card, Theme.parchmentDim],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.gold.opacity(0.5), lineWidth: 1.2)
                )
                .shadow(color: Theme.woodShadow.opacity(0.25), radius: 6, x: 0, y: 4)

            // Cinnabar accent stripe across the middle.
            Rectangle()
                .fill(Theme.cinnabar)
                .frame(height: 22)
                .overlay(
                    Rectangle()
                        .stroke(Theme.gold.opacity(0.75), lineWidth: 0.8)
                )
                .offset(y: 18)

            // Slot opening — dark capsule cutout at the top.
            VStack {
                Capsule()
                    .fill(Theme.woodShadow.opacity(0.65))
                    .frame(width: 140, height: 14)
                    .overlay(
                        Capsule().stroke(Theme.cinnabarDeep.opacity(0.55), lineWidth: 0.8)
                    )
                    .padding(.top, 18)
                Spacer()
            }
        }
    }
}

// MARK: - Single tissue (visible portion above the slot)

private struct TissueShape: View {
    var body: some View {
        ZStack {
            // Body — white with a hint of warm gradient so it reads on parchment.
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white,
                                 Color(red: 0.97, green: 0.96, blue: 0.93)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(red: 0.80, green: 0.78, blue: 0.74), lineWidth: 0.8)
                )

            // Subtle fold lines.
            VStack(spacing: 0) {
                ForEach(0..<5) { i in
                    Rectangle()
                        .fill(Color(red: 0.85, green: 0.83, blue: 0.78).opacity(0.55))
                        .frame(height: 0.7)
                        .padding(.vertical, CGFloat(3 + (i % 2) * 2))
                }
            }
            .padding(.horizontal, 10)

            // Soft diagonal crease across the middle.
            Path { p in
                p.move(to: CGPoint(x: 8, y: 36))
                p.addQuadCurve(
                    to: CGPoint(x: 122, y: 48),
                    control: CGPoint(x: 65, y: 18)
                )
            }
            .stroke(Color(red: 0.82, green: 0.80, blue: 0.75).opacity(0.75), lineWidth: 0.9)
        }
        .shadow(color: Theme.woodShadow.opacity(0.18), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Settings sheet

private struct TissueSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var labelYes: String
    @Binding var labelNo: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("tissues.default.yes", text: $labelYes)
                    TextField("tissues.default.no",  text: $labelNo)
                } header: {
                    Text("tissues.labels.title")
                } footer: {
                    Text("tissues.settings.footer")
                }
            }
            .navigationTitle("tissues.settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
