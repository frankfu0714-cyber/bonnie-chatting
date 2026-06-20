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

    // MARK: - Slot tissue + falling-tissue queue

    /// User's live drag translation on the SLOT tissue (negative = up).
    /// Resets to 0 the instant the slot tissue is "released" — independent
    /// fall animations are owned by `fallingTissues`.
    @State private var dragY: CGFloat = 0
    /// True once the drag has passed the resistance threshold.
    @State private var hasSnapped: Bool = false
    /// True only for the final tissue — lifted with a soft glow as the reveal.
    @State private var finalLift: Bool = false

    /// Independent "in-flight" tissues. Each one has its own
    /// `FallingTissueView` with self-managed onAppear → peak → fall →
    /// crumple → fade lifecycle. The slot is INSTANTLY ready for the next
    /// pull the moment one of these is spawned.
    @State private var fallingTissues: [FallingDescriptor] = []

    /// One-time "10-15 sheets in this pack" hint that fades in at the
    /// start of each round and self-dismisses after a few seconds. The
    /// user learns the ROUND'S RANGE but never sees a running count, so
    /// they can't pre-compute which tissue is last.
    @State private var roundIntroVisible: Bool = false

    /// Timestamp of the last accepted pull. Pulls within 100ms of the
    /// previous one are ignored — guards against a single physical
    /// gesture being dispatched twice (e.g., Button tap + DragGesture
    /// onEnded both firing on the same touch-up).
    @State private var lastPullAt: Date = .distantPast

    struct FallingDescriptor: Identifiable, Equatable {
        let id = UUID()
        /// Starting Y offset (relative to the inner ZStack center), so the
        /// fall begins exactly where the user released the slot tissue.
        let startY: CGFloat
        /// Drag-end velocity that flavors the launch.
        let velocityY: CGFloat
    }

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
        VStack(spacing: 0) {
            // Headroom ABOVE the box — CONDITIONALLY allocated only during
            // the final reveal so normal play keeps the box snug against
            // the cards above. Triggers a spring-animated layout shift
            // when finalLift flips, so the box smoothly drops down to
            // make room for the floating tissue rather than snapping.
            if finalLift {
                ZStack {
                    // Stronger golden halo behind the floating tissue —
                    // makes the "revealed" state read unmistakably.
                    Capsule()
                        .fill(Theme.gold.opacity(0.75))
                        .frame(width: 170, height: 130)
                        .blur(radius: 30)
                        .transition(.opacity)
                    // Free-floating final tissue — smaller (90×72) than the
                    // slot tissues so it reads as a single isolated sheet
                    // lifted away from the box, with a balloon-style ground
                    // shadow on the cream below.
                    FinalRevealTissueView()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .transition(.opacity)
            }

            // Box area — slot tissue, box body, the regular pulling
            // interaction. The final-reveal float-tissue is NOT in here.
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
                    // Box body (with the dark slot capsule inside) renders
                    // first — it's the backdrop. Both the slot tissue and the
                    // incoming tissue are drawn on top of the box, but each
                    // is MASKED so only the portion ABOVE the slot's top edge
                    // is visible. The masked-away bottom portion lets the box
                    // body (and its dark slot graphic) show through, which
                    // reads as the tissue emerging from inside the slot.
                    TissueBoxShape()
                        .frame(width: 240, height: 150)
                        .offset(y: 50)

                    // The NEXT tissue — pinned at the slot resting position
                    // and immobile. Only shown at full rest; hidden while
                    // any pull or fall is in progress so the user sees only
                    // the tissue they're currently pulling. Restored
                    // instantly via `.transition(.identity)` once the cycle
                    // finishes.
                    if showIncoming {
                        TissueShape()
                            .frame(width: 130, height: 96)
                            .mask(alignment: .top) { aboveSlotMask(offsetY: -38) }
                            .offset(y: -38)
                            .transition(.identity)
                    }

                    // The SLOT tissue — render a VERY TALL tissue (130×300)
                    // anchored with its BOTTOM at the slot top (stage_y = -7).
                    // Hidden during the final reveal — the slot is empty
                    // (no tissues left in the box) and the revealed tissue
                    // floats in the headroom area above.
                    if !finalLift {
                        let visibleHeight: CGFloat = 79 + max(0, -dragY)
                        TissueShape()
                            .frame(width: 130, height: 300)
                            .mask(alignment: .bottom) {
                                Rectangle()
                                    .frame(width: 200, height: visibleHeight)
                            }
                            .offset(y: -157)
                            .allowsHitTesting(false)
                            .transition(.identity)
                    }

                    Button {
                        dispatchPull(velocityY: -300)
                    } label: {
                        Color.clear
                            .frame(width: 170, height: 130)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(y: -38)
                    .allowsHitTesting(canInteract)
                    .simultaneousGesture(unifiedGesture)

                    // Independent in-flight tissues — detached from the slot,
                    // tumble away freely without the slot mask.
                    ForEach(fallingTissues) { desc in
                        FallingTissueView(startY: desc.startY,
                                          velocityY: desc.velocityY) {
                            withTransaction(Transaction(animation: nil)) {
                                fallingTissues.removeAll { $0.id == desc.id }
                            }
                        }
                        .transition(.identity)
                    }
                }
                .frame(height: 260)

                // Bottom-center: alternation hint + transient round intro.
                VStack(spacing: 6) {
                    Spacer()
                    if roundIntroVisible {
                        Text("tissues.round_intro")
                            .font(Theme.body(11, weight: .semibold))
                            .foregroundStyle(Theme.inkQuiet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.parchmentDim.opacity(0.7)))
                            .overlay(Capsule().stroke(Theme.rule, lineWidth: 0.8))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    if revealedLabel == nil {
                        nextHintPill
                    }
                }
                .padding(.bottom, 6)
            }
            .frame(height: 320)
        }
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

    /// Only blocks input once the reveal card is up. Otherwise the slot
    /// is ALWAYS interactive — no animation lock.
    private var canInteract: Bool {
        revealedLabel == nil
    }

    /// Whether to render the "next" tissue behind the one being pulled.
    ///
    /// Hidden while ANY pull is in progress — Frank's mental model is
    /// that there should only be ONE tissue visible while pulling, and
    /// seeing the incoming peek out of the slot at the same time reads
    /// as "two tissues being pulled". So: only show it at full rest.
    /// Also gated on the final tissue (nothing queued) and the reveal
    /// having fired.
    private var showIncoming: Bool {
        revealedLabel == nil
            && remaining > 1
            && dragY == 0
            && fallingTissues.isEmpty
    }

    /// Mask shape that exposes only the portion of a 96-pt-tall tissue
    /// whose pixels sit ABOVE the slot's top edge (stage_y = -7). The
    /// masked-away bottom is "inside the box" — covered by the box body
    /// underneath, including its dark slot graphic.
    ///
    /// Implementation: a tall Rectangle aligned to the tissue's frame
    /// top, then offset so its bottom edge falls at `local_y = -48 +
    /// visibleHeight` where visibleHeight is the count of pixels above
    /// the slot. The tall (1000pt) rect generously covers any portion
    /// the bottom-anchored scaleEffect stretches above the frame top.
    @ViewBuilder
    private func aboveSlotMask(offsetY: CGFloat) -> some View {
        // stage_y of a tissue pixel = local_y + offsetY.
        // Show pixels with stage_y ≤ -7 (slot top).
        // So show pixels with local_y ≤ -7 - offsetY.
        // In a 96-tall frame (local_y -48...48), visible height from top
        // is (-7 - offsetY) - (-48) = 41 - offsetY, clamped to [0, 96].
        let visibleHeight = max(0, min(96, 41 - offsetY))
        Rectangle()
            .frame(width: 500, height: 1000)
            .offset(y: visibleHeight - 1000)
    }

    private func startNewRound() {
        questionFocused = false
        firstPluckYes = Bool.random()
        pluckCount = 0
        revealedLabel = nil
        // 10-15 keeps the round shorter and, combined with the random
        // first-pluck-label, makes the final tissue genuinely
        // unpredictable. The user is shown the RANGE but never the
        // running count.
        totalCount = Int.random(in: 10...15)
        remaining = totalCount
        // Spring the headroom slot back closed so the box smoothly rises
        // up after a final-reveal round, mirroring the open animation.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            finalLift = false
        }
        hasSnapped = false
        dragY = 0
        clearFallingTissues()

        // Briefly show the "10-15 sheets in this pack" intro hint.
        withAnimation(.easeOut(duration: 0.35)) {
            roundIntroVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.45)) {
                roundIntroVisible = false
            }
        }
    }

    // MARK: - Drag interaction

    /// Drag-only gesture. `minimumDistance: 10` keeps pure taps from
    /// tripping the drag path — those are handled by the Button wrapper.
    private var unifiedGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                handleDragChange(value)
            }
            .onEnded { value in
                handleDragEnd(value)
            }
    }

    private func handleDragChange(_ value: DragGesture.Value) {
        guard revealedLabel == nil else { return }

        // Touchdown / any movement on the slot tissue evicts any in-flight
        // ghost from a previous pull. Unconditional — runs even before we
        // know if this gesture is going to be a tap, a drag, or just a
        // jitter. Cheap if the array is already empty.
        clearFallingTissues()

        let raw = value.translation.height
        guard raw < 0 else {
            dragY = 0
            return
        }

        let amount = -raw  // positive: pulled up by this much

        if !hasSnapped, amount < 30 {
            // Resistance phase — tissue grows just slightly.
            dragY = -amount * 0.4
        } else {
            if !hasSnapped {
                hasSnapped = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            // Past the snap, every pt of drag adds 1pt of visible
            // height to the tissue. Capped at 200pt of pull so it
            // doesn't fly off the top of the stage.
            dragY = -min(amount, 200)
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        guard revealedLabel == nil, remaining > 0 else { return }

        let raw = value.translation.height
        let velocityY = value.predictedEndTranslation.height - value.translation.height

        // Real upward pull past the snap threshold — release with the
        // gesture's actual velocity.
        if hasSnapped, raw < -50 {
            dispatchPull(velocityY: velocityY)
            return
        }

        // Anything else (downward drag, short cancel-pull) — spring back.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            dragY = 0
        }
        hasSnapped = false
    }

    /// Single dispatch path used by both the Button (tap) and the drag's
    /// onEnded. A 100ms debounce on `lastPullAt` rejects a second call
    /// triggered by the same physical gesture (e.g., Button tap fires
    /// alongside a tiny-movement DragGesture onEnded) so the user gets
    /// exactly one pull per intent.
    private func dispatchPull(velocityY: CGFloat) {
        let now = Date()
        guard now.timeIntervalSince(lastPullAt) >= 0.1 else { return }
        lastPullAt = now

        // Strictly one in-flight tissue at a time. Replace any residue
        // from the previous pull before spawning the new one — animation
        // explicitly disabled so SwiftUI can't keep a stale view alive
        // through an implicit removal transition.
        clearFallingTissues()

        if remaining == 1 {
            triggerFinalReveal()
            return
        }

        // The falling tissue spawns at the visible center of the slot
        // tissue's CURRENT stretched form, so the released tissue
        // appears to detach from exactly where the user was holding it.
        // Slot top is at stage_y = -7; visible tissue height is
        // (79 + max(0, -dragY)); visible center = -7 - height/2.
        let visibleHeight = 79.0 + max(0, -dragY)
        let visibleCenterY = -7.0 - visibleHeight / 2.0
        spawnFallingTissue(startY: visibleCenterY, velocityY: velocityY)
        dragY = 0
        hasSnapped = false
    }

    /// Single source of truth for evicting in-flight falling tissues.
    /// Wrapped in a no-animation transaction so the removal is *immediate*
    /// — combined with `.transition(.identity)` on the ForEach, there's
    /// no frame in which a removed tissue is still visible.
    private func clearFallingTissues() {
        guard !fallingTissues.isEmpty else { return }
        withTransaction(Transaction(animation: nil)) {
            fallingTissues.removeAll()
        }
    }

    /// Append a new in-flight tissue at the given stage_y and decrement
    /// the count. Capped at 1 active falling tissue (see below).
    private func spawnFallingTissue(startY: CGFloat, velocityY: CGFloat) {
        fallingTissues.append(.init(startY: startY, velocityY: velocityY))
        if fallingTissues.count > 1 {
            fallingTissues.removeFirst(fallingTissues.count - 1)
        }
        remaining -= 1
        pluckCount += 1
        AudioServicesPlaySystemSound(1306)
    }

    /// Final-tissue path — the tissue detaches from the slot and floats
    /// in the reserved headroom area above the (now empty) box, with a
    /// golden glow halo. The slot below is rendered empty since there
    /// are no tissues left.
    private func triggerFinalReveal() {
        let label = nextLabel
        revealedLabel = label
        hasSnapped = false
        // Spring so the box smoothly drops down to make room as the
        // headroom slot allocates, instead of snapping into place.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            finalLift = true
            // Reset the slot drag — the final tissue is no longer
            // slot-anchored, so the pulled-stretch state is irrelevant.
            dragY = 0
        }
    }
}

// MARK: - Final reveal tissue (free-floating, gentle bob)

/// The last tissue rendered as a free-floating element above the slot,
/// smaller than the slot tissues (90×72 vs 130×96) so it reads as a
/// single isolated sheet lifted away. A static balloon-style ground
/// shadow on the cream below reinforces the "hovering" effect while the
/// tissue itself bobs and tilts gently.
private struct FinalRevealTissueView: View {
    @State private var bobOffset: CGFloat = 0
    @State private var tilt: Double = 0

    var body: some View {
        ZStack {
            // Ground shadow — stays put while the tissue bobs above it.
            Ellipse()
                .fill(Color.black.opacity(0.14))
                .frame(width: 72, height: 14)
                .blur(radius: 6)
                .offset(y: 56)

            TissueShape()
                .frame(width: 90, height: 72)
                .rotationEffect(.degrees(tilt))
                .offset(y: bobOffset)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                bobOffset = -6
            }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                tilt = 1.5
            }
        }
    }
}

// MARK: - Falling tissue (self-managed animation lifecycle)

/// An independent in-flight tissue. Owns its own animation state so
/// multiple instances can coexist on screen at different stages of their
/// fall. Self-removes via `onComplete` after ~1.5s.
private struct FallingTissueView: View {
    let startY: CGFloat
    let velocityY: CGFloat
    let onComplete: () -> Void

    @State private var offsetY: CGFloat
    @State private var driftX: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    init(startY: CGFloat, velocityY: CGFloat, onComplete: @escaping () -> Void) {
        self.startY = startY
        self.velocityY = velocityY
        self.onComplete = onComplete
        _offsetY = State(initialValue: startY)
    }

    var body: some View {
        TissueShape()
            .frame(width: 130, height: 96)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: driftX, y: offsetY)
            .allowsHitTesting(false)
            .onAppear(perform: runLifecycle)
    }

    private func runLifecycle() {
        // Lift amount = baseline 40pt + velocity contribution (capped at 100pt).
        let liftAmount = max(40, min(100, abs(velocityY) * 0.30))
        let peakY = startY - liftAmount
        let randomDrift = CGFloat.random(in: -70...70)
        let randomTumble = Double.random(in: -85...85)

        // Phase 1 — brief upward peak carrying release momentum.
        withAnimation(.easeOut(duration: 0.22)) {
            offsetY = peakY
        }

        // Phase 2 — gravity. Falls offscreen, tumbles, crumples, fades.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeIn(duration: 0.85)) {
                offsetY = 520
            }
            withAnimation(.linear(duration: 0.85)) {
                rotation = randomTumble
                driftX = randomDrift
            }
            withAnimation(.easeIn(duration: 0.55).delay(0.15)) {
                scale = 0.82
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.40)) {
                opacity = 0
            }
        }

        // Cleanup — remove from the parent's queue.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) {
            onComplete()
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
