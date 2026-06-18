import SwiftUI
import AudioToolbox

struct CoinFlipView: View {

    // MARK: - Per-question state

    @AppStorage("coin.question") private var question: String = ""
    @AppStorage("coin.labelZi")  private var labelZi: String = ""    // 字
    @AppStorage("coin.labelMu")  private var labelMu: String = ""    // 幕

    @FocusState private var questionFocused: Bool
    @State private var showingSettings = false

    // MARK: - Flip state

    private enum Face: Equatable { case zi, mu }
    @State private var face: Face = .zi
    @State private var rotation: Double = 0           // around Y axis, degrees
    @State private var hover: Double = 0              // vertical bounce during flip
    @State private var spinning: Bool = false
    @State private var settled: Bool = false
    @State private var revealVisible: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                questionCard
                settingsCard
                stage
                if settled, revealVisible {
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
        .sheet(isPresented: $showingSettings) {
            CoinSettingsSheet(labelZi: $labelZi, labelMu: $labelMu)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Computed

    private var ziLabel: String {
        labelZi.isEmpty ? NSLocalizedString("coin.default.zi", comment: "") : labelZi
    }
    private var muLabel: String {
        labelMu.isEmpty ? NSLocalizedString("coin.default.mu", comment: "") : labelMu
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("coin.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("coin.question.placeholder", text: $question, axis: .vertical)
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
                Image(systemName: "character.book.closed")
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("coin.settings.title")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 6) {
                        Text("字").foregroundStyle(Theme.cinnabarDeep).font(Theme.headlineSerif(13, weight: .semibold))
                        Text(verbatim: ziLabel).font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                        Text("·").foregroundStyle(Theme.inkQuiet)
                        Text("幕").foregroundStyle(Theme.cinnabarDeep).font(Theme.headlineSerif(13, weight: .semibold))
                        Text(verbatim: muLabel).font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
                    }
                    .lineLimit(1)
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
                        colors: [Theme.gold.opacity(0.30), Theme.parchment.opacity(0)],
                        center: .center, startRadius: 30, endRadius: 200
                    )
                )
                .frame(height: 300)

            // Ground shadow under the coin.
            Ellipse()
                .fill(Theme.woodShadow.opacity(0.30))
                .frame(width: 140, height: 18)
                .blur(radius: 6)
                .offset(y: 86)

            // Both faces stacked. Each uses rotation3DEffect so SwiftUI handles
            // mirroring — we draw the back face pre-rotated by 180° so its
            // characters read correctly when the coin is back-up.
            ZStack {
                coinFace(label: ziLabel, primary: true)
                    .rotation3DEffect(.degrees(rotation), axis: (0, 1, 0))
                    .opacity(showZi ? 1 : 0)
                coinFace(label: muLabel, primary: false)
                    .rotation3DEffect(.degrees(rotation + 180), axis: (0, 1, 0))
                    .opacity(showZi ? 0 : 1)
            }
            .offset(y: hover)
        }
        .frame(height: 300)
    }

    /// Which face is currently presented to the viewer (mod 360°).
    private var showZi: Bool {
        let r = ((rotation.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        return r < 90 || r > 270
    }

    private func coinFace(label: String, primary: Bool) -> some View {
        ZStack {
            // Coin body — brass / copper radial gradient.
            Circle()
                .fill(
                    RadialGradient(
                        colors: primary
                            ? [Color(red: 0.90, green: 0.75, blue: 0.40),
                               Color(red: 0.66, green: 0.48, blue: 0.18)]
                            : [Color(red: 0.78, green: 0.60, blue: 0.28),
                               Color(red: 0.50, green: 0.34, blue: 0.10)],
                        center: .topLeading, startRadius: 10, endRadius: 200
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    Circle().stroke(Theme.goldDeep.opacity(0.7), lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(Theme.cinnabarDeep.opacity(0.35), lineWidth: 1)
                        .padding(8)
                )

            // Four characters around a square hole (only on 字 side).
            // 幕 side is left more "blank" — just a faint inscription label.
            if primary {
                ForEach(0..<4) { i in
                    Text(quadrantChar(label, i))
                        .font(Theme.headlineSerif(28, weight: .bold))
                        .foregroundStyle(Theme.cinnabarDeep)
                        .offset(coinOffset(for: i))
                }
            } else {
                Text(label)
                    .font(Theme.headlineSerif(22, weight: .semibold))
                    .foregroundStyle(Theme.cinnabarDeep.opacity(0.6))
                    .frame(width: 140)
                    .multilineTextAlignment(.center)
                    .offset(y: -60)
            }

            // Square hole in the middle.
            Rectangle()
                .fill(Theme.parchment)
                .overlay(Rectangle().stroke(Theme.woodDark.opacity(0.6), lineWidth: 1.2))
                .frame(width: 38, height: 38)
        }
        .shadow(color: Theme.woodShadow.opacity(0.30), radius: 6, x: 0, y: 3)
    }

    /// Pick a single character for each quadrant. If the label has 4+ chars,
    /// use them around the hole; otherwise repeat / pad so the coin still
    /// looks like a 銅錢.
    private func quadrantChar(_ s: String, _ i: Int) -> String {
        let chars = Array(s)
        guard !chars.isEmpty else { return "" }
        // Quadrants: 0 = top, 1 = right, 2 = bottom, 3 = left.
        if chars.count >= 4 {
            return String(chars[i % chars.count])
        }
        // For 1-3 character labels, reuse the available chars so each quadrant
        // shows something — gives the coin its distinctive 4-character look.
        return String(chars[i % chars.count])
    }

    private func coinOffset(for i: Int) -> CGSize {
        let r: CGFloat = 56
        switch i {
        case 0: return CGSize(width: 0, height: -r)
        case 1: return CGSize(width: r, height: 0)
        case 2: return CGSize(width: 0, height: r)
        default: return CGSize(width: -r, height: 0)
        }
    }

    private var revealCard: some View {
        let landingLabel = (face == .zi) ? ziLabel : muLabel
        let landingFace = (face == .zi) ? "字" : "幕"
        return VStack(spacing: 8) {
            Text(verbatim: landingFace)
                .font(Theme.headlineSerif(28, weight: .bold))
                .foregroundStyle(Theme.cinnabarDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.gold.opacity(0.25))
                        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1))
                )
            Text(landingLabel)
                .font(Theme.headlineSerif(24, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(face == .zi ? "coin.reveal.zi_desc" : "coin.reveal.mu_desc")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSoft)
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
        Button { performFlip() } label: {
            HStack(spacing: 10) {
                Image(systemName: spinning ? "hourglass" : "hand.thumbsup")
                Text(spinning
                     ? "coin.action.flipping"
                     : (settled ? "coin.action.again" : "coin.action.flip"))
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
        .disabled(spinning)
        .opacity(spinning ? 0.7 : 1)
    }

    // MARK: - Flip

    private func performFlip() {
        questionFocused = false
        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }

        // True 50/50 outcome — independent of previous flips, the rotation
        // value, or any counter. Generated fresh per tap.
        let nextFace: Face = Bool.random() ? .zi : .mu

        // Spin animation: 4–7 full revolutions, plus the half-turn delta
        // needed to land with `nextFace` facing the viewer.
        let baseSpins = Double(Int.random(in: 4...7)) * 360.0
        let currentMod = ((rotation.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let targetMod: Double = (nextFace == .zi) ? 0 : 180
        var deltaToTarget = targetMod - currentMod
        if deltaToTarget < 0 { deltaToTarget += 360 }
        let target = rotation + baseSpins + deltaToTarget

        spinning = true
        settled = false

        withAnimation(.easeOut(duration: 1.4)) {
            rotation = target
        }
        withAnimation(.easeOut(duration: 0.7)) {
            hover = -50
        }
        withAnimation(.easeIn(duration: 0.6).delay(0.7)) {
            hover = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            face = nextFace
            spinning = false
            settled = true
            AudioServicesPlaySystemSound(1104)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                revealVisible = true
            }
        }
    }
}

// MARK: - Settings sheet

private struct CoinSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var labelZi: String
    @Binding var labelMu: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("coin.default.zi", text: $labelZi)
                } header: {
                    HStack(spacing: 6) {
                        Text("字").font(Theme.headlineSerif(15, weight: .bold))
                        Text("coin.settings.zi_header")
                    }
                } footer: {
                    Text("coin.settings.zi_footer")
                }
                Section {
                    TextField("coin.default.mu", text: $labelMu)
                } header: {
                    HStack(spacing: 6) {
                        Text("幕").font(Theme.headlineSerif(15, weight: .bold))
                        Text("coin.settings.mu_header")
                    }
                } footer: {
                    Text("coin.settings.mu_footer")
                }
            }
            .navigationTitle("coin.settings.title")
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
