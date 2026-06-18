import SwiftUI
import UIKit
import AudioToolbox

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

    // MARK: - Drag + animation state

    private enum Phase: Equatable { case idle, dragging, flying, rising, revealing }
    @State private var phase: Phase = .idle

    /// User's live drag translation (negative = up). Resets to 0 between pulls.
    @State private var dragY: CGFloat = 0
    /// Additional Y offset applied during the fly/fall release animation.
    @State private var releaseY: CGFloat = 0
    /// Sideways drift during fall.
    @State private var driftX: CGFloat = 0
    /// Tissue rotation in degrees (only used during fall).
    @State private var rotation: Double = 0
    /// Uniform scale (shrinks during fall as the tissue "crumples").
    @State private var scale: CGFloat = 1.0
    /// Vertical stretch anchored at the bottom — makes the tissue elongate
    /// as the user pulls it out, and "rise from the slot" as a fresh tissue
    /// emerges.
    @State private var stretch: CGFloat = 1.0
    /// Opacity for the fade-out at the end of a fall.
    @State private var tissueOpacity: Double = 1.0
    /// True once the drag has passed the resistance threshold for the round.
    @State private var hasSnapped: Bool = false
    /// True only for the final tissue — lifted with a soft glow as the reveal.
    @State private var finalLift: Bool = false
    /// True while a pull animation cycle is in progress. Blocks hit testing
    /// so a fast follow-up gesture (e.g. trackpad emulating multiple events
    /// from a single drag) can't fire a second pull mid-animation.
    @State private var isAnimating: Bool = false

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
                        .offset(y: -30 + dragY + releaseY)
                }

                // The tissue itself. Tap uses Button (reliable inside the
                // outer ScrollView). Drag uses a simultaneous DragGesture
                // with a 10pt minimum distance so a pure tap doesn't trip
                // the drag path.
                Button {
                    performTapPull()
                } label: {
                    TissueShape()
                        .frame(width: 130, height: 96)
                        .scaleEffect(x: 1, y: stretch, anchor: .bottom)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                        .opacity(tissueOpacity)
                        .frame(width: 170, height: 130)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: driftX, y: -38 + dragY + releaseY)
                .allowsHitTesting(canInteract)
                .simultaneousGesture(dragOnlyGesture)
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

    private var canInteract: Bool {
        revealedLabel == nil && !isAnimating && (phase == .idle || phase == .dragging)
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
        hasSnapped = false
        dragY = 0
        releaseY = 0
        driftX = 0
        rotation = 0
        scale = 1.0
        stretch = 1.0
        tissueOpacity = 1.0
    }

    // MARK: - Drag interaction

    /// Drag-only gesture. `minimumDistance: 10` keeps it out of the way of
    /// the Button's tap recognizer — a pure tap never trips this path.
    private var dragOnlyGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                handleDragChange(value)
            }
            .onEnded { value in
                handleDragEnd(value)
            }
    }

    private func handleDragChange(_ value: DragGesture.Value) {
        guard !isAnimating, phase == .idle || phase == .dragging else { return }
        if phase == .idle { phase = .dragging }

        let raw = value.translation.height
        // Only treat upward (negative-y) motion as a pull. Ignore downward drag.
        guard raw < 0 else {
            dragY = 0
            stretch = 1.0
            return
        }

        let amount = -raw  // positive: how far the user has pulled UP

        if !hasSnapped, amount < 30 {
            // Resistance phase — tissue resists, offset is dampened to 40%.
            dragY = -amount * 0.4
            stretch = 1.0 + amount * 0.004
        } else {
            if !hasSnapped {
                hasSnapped = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            // 1:1 tracking past the snap threshold.
            dragY = -amount
            // Tissue elongates as more emerges from the slot.
            stretch = 1.0 + min(amount / 90, 0.7)
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        guard !isAnimating, phase == .dragging else {
            return
        }

        let raw = value.translation.height
        let velocityY = value.predictedEndTranslation.height - value.translation.height

        // Successful pull — past the snap threshold AND moved at least 50pt up.
        if hasSnapped, raw < -50 {
            performRelease(velocityY: velocityY)
            return
        }

        // Cancelled drag — snap the tissue back to rest.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            dragY = 0
            stretch = 1.0
        }
        hasSnapped = false
        phase = .idle
    }

    /// Tap shortcut — simulates a quick pull-up and then a release with a
    /// modest preset velocity, so non-draggers still get the satisfying
    /// release physics.
    private func performTapPull() {
        guard !isAnimating, revealedLabel == nil, remaining > 0 else { return }
        isAnimating = true
        hasSnapped = true
        phase = .dragging

        withAnimation(.easeOut(duration: 0.14)) {
            dragY = -55
            stretch = 1.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            runReleaseInternal(velocityY: -350)
        }
    }

    /// Common release path: final-tissue reveal vs. fly-fall-respawn.
    /// Public entry from `handleDragEnd` — applies the animation lock.
    private func performRelease(velocityY: CGFloat) {
        guard !isAnimating else { return }
        isAnimating = true
        runReleaseInternal(velocityY: velocityY)
    }

    /// Internal release logic — assumes `isAnimating` is already set so it
    /// can be called from `performTapPull` after its own lock-and-prep step
    /// without re-locking.
    private func runReleaseInternal(velocityY: CGFloat) {
        // Final tissue → hold with reverence and reveal.
        if remaining == 1 {
            let label = nextLabel
            revealedLabel = label
            phase = .revealing
            withAnimation(.easeOut(duration: 0.95)) {
                finalLift = true
                dragY = -55
                stretch = 1.0
            }
            return
        }

        phase = .flying

        // Velocity gives the release a little extra "lift" at the peak,
        // capped so a flick doesn't fling it absurdly far.
        let momentum = max(-90, min(0, velocityY * 0.35))
        let randomDrift = CGFloat.random(in: -70...70)
        let randomTumble = Double.random(in: -85...85)

        // Phase 1: brief upward continuation — momentum from the user's pull.
        withAnimation(.easeOut(duration: 0.22)) {
            dragY = dragY + momentum
            stretch = 1.0   // snaps free of the box, no more stretching
        }

        // Phase 2: gravity. Falls past the start, tumbles, crumples, fades.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeIn(duration: 0.85)) {
                releaseY = 520
            }
            withAnimation(.linear(duration: 0.85)) {
                rotation = randomTumble
                driftX = randomDrift
            }
            withAnimation(.easeIn(duration: 0.55).delay(0.15)) {
                scale = 0.82
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.40)) {
                tissueOpacity = 0
            }

            // Soft paper "swish" on release.
            AudioServicesPlaySystemSound(1306)
        }

        // After the fall completes: decrement, reset state, animate the next
        // tissue rising from the slot with a small overshoot bounce.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) {
            remaining -= 1
            pluckCount += 1
            hasSnapped = false

            // Reset transient transforms — the next tissue starts from inside
            // the slot (stretch ≈ 0 keeps it flat against the slot line).
            dragY = 0
            releaseY = 0
            driftX = 0
            rotation = 0
            scale = 1.0
            stretch = 0.05
            tissueOpacity = 1.0
            phase = .rising

            // Overshoot to 1.1 then settle to 1.0 — feels like the box's
            // tension pushes the next tissue up.
            withAnimation(.interpolatingSpring(stiffness: 220, damping: 13)) {
                stretch = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                phase = .idle
                isAnimating = false
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
