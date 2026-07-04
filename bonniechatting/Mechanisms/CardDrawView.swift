import SwiftUI
import AudioToolbox

struct CardDrawView: View {

    // MARK: - Per-question state (persists)

    @AppStorage("carddraw.question") private var question: String = ""
    /// Newline-separated options. Default seeded on first appear.
    @AppStorage("carddraw.options")  private var optionsRaw: String = ""

    @FocusState private var questionFocused: Bool
    @State private var showingSettings = false

    // MARK: - Animation state

    private enum Phase: Equatable {
        case idle
        case drawing
        case settled(Int)   // winning option index (0-based)
    }
    @State private var phase: Phase = .idle
    @State private var drawnOffset: CGSize = .zero
    @State private var drawnRotation: Angle = .zero
    @State private var drawnFlip: Double = 0        // 0 = back, 180 = face
    @State private var drawnIndex: Int? = nil
    @State private var deckShuffleTick: Int = 0
    @State private var revealVisible: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                questionCard
                settingsCard
                stage
                if case let .settled(idx) = phase, revealVisible {
                    revealCard(index: idx)
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
            if optionsRaw.isEmpty {
                optionsRaw = NSLocalizedString("carddraw.default.options", comment: "")
            }
        }
        .sheet(isPresented: $showingSettings) {
            CardDrawSettingsSheet(optionsRaw: $optionsRaw)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Computed

    private var options: [String] {
        optionsRaw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var n: Int { max(1, options.count) }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("carddraw.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("carddraw.question.placeholder", text: $question, axis: .vertical)
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
                Image(systemName: "list.bullet")
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("carddraw.settings.title")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(options.isEmpty ? "—" : options.joined(separator: " · "))
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkQuiet)
                        .lineLimit(2)
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
                        colors: [Theme.gold.opacity(0.22), Theme.parchment.opacity(0)],
                        center: .center, startRadius: 30, endRadius: 200
                    )
                )
                .frame(width: 340, height: 300)
                .offset(y: 40)

            // Deck stack — three background cards for depth.
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    CardBack()
                        .frame(width: 150, height: 210)
                        .offset(x: CGFloat(i) * 3, y: CGFloat(-i) * 3)
                        .rotationEffect(.degrees(Double(i) * -2))
                        .opacity(1.0 - Double(i) * 0.06)
                        .shadow(color: Theme.woodShadow.opacity(0.15), radius: 3, x: 0, y: 2)
                }
            }
            .id(deckShuffleTick)

            // The drawn card sits above the deck; front shows the picked option.
            if let idx = drawnIndex {
                CardFace(
                    label: options.indices.contains(idx) ? options[idx] : "—",
                    number: idx + 1
                )
                .frame(width: 150, height: 210)
                .rotation3DEffect(
                    .degrees(drawnFlip),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.6
                )
                .offset(drawnOffset)
                .rotationEffect(drawnRotation)
                .shadow(color: Theme.woodShadow.opacity(0.25), radius: 8, x: 0, y: 6)
                // Hide the back side of the flip so we don't see mirrored text.
                .opacity(drawnFlip.truncatingRemainder(dividingBy: 360) < 90
                         || drawnFlip.truncatingRemainder(dividingBy: 360) > 270 ? 1 : 0)
            }
        }
        .frame(height: 300)
        .padding(.top, 10)
    }

    private func revealCard(index: Int) -> some View {
        let label = options.indices.contains(index) ? options[index] : "—"
        return VStack(spacing: 12) {
            Text("carddraw.reveal.prefix")
                .font(Theme.headlineSerif(20, weight: .semibold))
                .foregroundStyle(Theme.cinnabar)

            Text(label)
                .font(Theme.headlineSerif(28, weight: .bold))
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
        Button { performDraw() } label: {
            HStack(spacing: 10) {
                Image(systemName: phase == .drawing ? "hourglass" : "hand.tap")
                Text(phase == .drawing
                     ? "carddraw.action.drawing"
                     : (isSettled ? "carddraw.action.again" : "carddraw.action.draw"))
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
        .disabled(phase == .drawing || options.isEmpty)
        .opacity(phase == .drawing ? 0.7 : (options.isEmpty ? 0.5 : 1))
    }

    private var isSettled: Bool {
        if case .settled = phase { return true }
        return false
    }

    // MARK: - Animation

    private func performDraw() {
        guard !options.isEmpty else { return }
        questionFocused = false
        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }

        // Reset the drawn card to face-down atop the deck.
        drawnIndex = nil
        drawnOffset = .zero
        drawnRotation = .zero
        drawnFlip = 0
        deckShuffleTick &+= 1
        phase = .drawing

        let winner = Int.random(in: 0..<n)
        drawnIndex = winner

        // Slide up and to the right, then flip.
        withAnimation(.easeOut(duration: 0.4)) {
            drawnOffset = CGSize(width: 40, height: -60)
            drawnRotation = .degrees(6)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            AudioServicesPlaySystemSound(1104)
            withAnimation(.easeInOut(duration: 0.55)) {
                drawnFlip = 180
                drawnOffset = CGSize(width: 0, height: -20)
                drawnRotation = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                phase = .settled(winner)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    revealVisible = true
                }
            }
        }
    }
}

// MARK: - Card visuals

private struct CardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.card, Theme.parchmentDim],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.gold.opacity(0.6), lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.gold.opacity(0.35), lineWidth: 1)
                    .padding(10)
            )
            .overlay(
                Image(systemName: "diamond.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.cinnabar.opacity(0.55))
            )
    }
}

private struct CardFace: View {
    let label: String
    let number: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.gold, lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                    .padding(10)
            )
            .overlay(
                VStack {
                    HStack {
                        Text("\(number)")
                            .font(Theme.headlineSerif(16, weight: .semibold))
                            .foregroundStyle(Theme.cinnabarDeep)
                        Spacer()
                    }
                    Spacer()
                    Text(label)
                        .font(Theme.headlineSerif(22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(number)")
                            .font(Theme.headlineSerif(16, weight: .semibold))
                            .foregroundStyle(Theme.cinnabarDeep)
                            .rotationEffect(.degrees(180))
                    }
                }
                .padding(16)
            )
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }
}

// MARK: - Settings sheet

private struct CardDrawSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var optionsRaw: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $optionsRaw)
                        .font(Theme.body(16))
                        .frame(minHeight: 200)
                } header: {
                    Text("carddraw.settings.list_header")
                } footer: {
                    Text("carddraw.settings.list_footer")
                }
            }
            .navigationTitle("carddraw.settings.title")
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
