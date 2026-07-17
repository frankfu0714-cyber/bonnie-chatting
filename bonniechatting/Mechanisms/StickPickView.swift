import SwiftUI

struct StickPickView: View {

    // MARK: - Per-question state (persists)

    @AppStorage("stickpick.question") private var question: String = ""
    /// Newline-separated user customisations. Empty = use locale-aware defaults.
    @AppStorage("stickpick.options")  private var optionsRaw: String = ""

    @Environment(\.locale) private var locale
    @FocusState private var questionFocused: Bool
    @State private var showingSettings = false

    // MARK: - Animation state

    private enum Phase: Equatable {
        case idle
        case shaking
        case settled(Int)   // winning option index (0-based)
    }
    @State private var phase: Phase = .idle
    @State private var cylinderTilt: Angle = .zero
    @State private var stickJitter: Double = 0
    @State private var fallenIndex: Int? = nil
    @State private var fallenOffset: CGSize = .zero
    @State private var fallenRotation: Angle = .zero
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
        .sheet(isPresented: $showingSettings) {
            StickPickSettingsSheet(optionsRaw: $optionsRaw)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Computed

    /// User customisations if present; otherwise the locale-aware defaults.
    /// Computed live so toggling the in-app language picker updates the
    /// displayed options without needing to re-seed `@AppStorage`.
    private var effectiveOptionsRaw: String {
        optionsRaw.isEmpty
            ? String.appLocalized("stickpick.default.options", locale: locale)
            : optionsRaw
    }

    private var options: [String] {
        effectiveOptionsRaw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var n: Int { max(1, options.count) }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("stickpick.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("stickpick.question.placeholder", text: $question, axis: .vertical)
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
                    Text("stickpick.settings.title")
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
                        colors: [Theme.gold.opacity(0.25), Theme.parchment.opacity(0)],
                        center: .center, startRadius: 30, endRadius: 200
                    )
                )
                .frame(width: 340, height: 320)
                .offset(y: 70)

            ZStack(alignment: .bottom) {
                ForEach(0..<n, id: \.self) { i in
                    StickShape(numeral: StickNumeral.of(i + 1),
                               isFallen: fallenIndex == i)
                        .offset(x: stickColumnOffset(for: i),
                                y: -135 + (fallenIndex == i ? 0 : sin(Double(i)) * 4))
                        .rotationEffect(stickAngle(for: i))
                }

                CylinderBody()
                    .frame(width: 130, height: 150)
            }
            .rotationEffect(cylinderTilt, anchor: .bottom)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 10)

            if let fi = fallenIndex {
                StickShape(numeral: StickNumeral.of(fi + 1), isFallen: true)
                    .rotationEffect(fallenRotation)
                    .offset(fallenOffset)
                    .transition(.opacity)
            }
        }
        .frame(height: 360)
        .padding(.top, 10)
    }

    private func stickColumnOffset(for i: Int) -> CGFloat {
        let spread: CGFloat = 70
        let step = n > 1 ? spread / CGFloat(n - 1) : 0
        return -spread / 2 + step * CGFloat(i)
    }

    private func stickAngle(for i: Int) -> Angle {
        let base = -10.0 + Double(i) * (20.0 / Double(max(1, n - 1)))
        return .degrees(base + stickJitter * sin(Double(i) * 2.1))
    }

    private func revealCard(index: Int) -> some View {
        let label = options.indices.contains(index) ? options[index] : "—"
        let numberText = "#" + StickNumeral.localized(index + 1, locale: locale)
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("stickpick.reveal.prefix")
                    .font(Theme.headlineSerif(20, weight: .semibold))
                    .foregroundStyle(Theme.cinnabar)
                Text(verbatim: numberText)
                    .font(Theme.headlineSerif(20, weight: .semibold))
                    .foregroundStyle(Theme.cinnabar)
            }

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
        Button { performShake() } label: {
            HStack(spacing: 10) {
                Image(systemName: phase == .shaking ? "hourglass" : "hand.raised.fingers.spread")
                Text(phase == .shaking
                     ? "stickpick.action.shaking"
                     : (isSettled ? "stickpick.action.again" : "stickpick.action.shake"))
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
        .disabled(phase == .shaking || options.isEmpty)
        .opacity(phase == .shaking ? 0.7 : (options.isEmpty ? 0.5 : 1))
    }

    private var isSettled: Bool {
        if case .settled = phase { return true }
        return false
    }

    // MARK: - Animation

    private func performShake() {
        guard !options.isEmpty else { return }
        questionFocused = false
        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }
        fallenIndex = nil
        phase = .shaking

        let winner = Int.random(in: 0..<n)

        let shakeDuration = 0.55
        withAnimation(.easeInOut(duration: shakeDuration / 6).repeatCount(6, autoreverses: true)) {
            cylinderTilt = .degrees(14)
            stickJitter = 6
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
            withAnimation(.easeOut(duration: 0.15)) {
                cylinderTilt = .zero
                stickJitter = 0
            }
            fallenIndex = winner
            fallenOffset = CGSize(width: 0, height: -40)
            fallenRotation = .degrees(Double.random(in: -10...10))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                fallenOffset = CGSize(width: CGFloat.random(in: -20...20), height: 110)
                fallenRotation = .degrees(Double.random(in: 70...100))
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

// MARK: - Cylinder

private struct CylinderBody: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.woodMid, Theme.woodDark, Theme.woodMid],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.gold.opacity(0.55), lineWidth: 1.2)
                )
                .overlay(
                    Rectangle()
                        .fill(Theme.cinnabarDeep.opacity(0.55))
                        .frame(height: 14)
                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.7), lineWidth: 0.8))
                )
        }
        .shadow(color: Theme.woodShadow.opacity(0.35), radius: 6, x: 0, y: 4)
    }
}

// MARK: - One stick

private struct StickShape: View {
    let numeral: String
    let isFallen: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.93, green: 0.83, blue: 0.55),
                                 Color(red: 0.74, green: 0.58, blue: 0.32)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Theme.woodDark.opacity(0.5), lineWidth: 0.6)
                )
                .frame(width: 14, height: 98)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.cinnabarDeep)
                        .frame(width: 14, height: 22)
                        .offset(y: -38),
                    alignment: .center
                )

            Text(numeral)
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(Color.white)
                .offset(y: -38)
        }
        .opacity(isFallen ? 1 : 0.96)
    }
}

// MARK: - Settings sheet

private struct StickPickSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Binding var optionsRaw: String
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft)
                        .font(Theme.body(16))
                        .frame(minHeight: 200)
                } header: {
                    Text("stickpick.settings.list_header")
                } footer: {
                    Text("stickpick.settings.list_footer")
                }
            }
            .navigationTitle("stickpick.settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") {
                        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        let localeDefault = String.appLocalized("stickpick.default.options", locale: locale)
                        optionsRaw = (trimmed.isEmpty || draft == localeDefault) ? "" : draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = optionsRaw.isEmpty
                    ? String.appLocalized("stickpick.default.options", locale: locale)
                    : optionsRaw
            }
        }
    }
}
