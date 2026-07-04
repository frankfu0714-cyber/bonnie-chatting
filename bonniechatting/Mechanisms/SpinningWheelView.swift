import SwiftUI

struct SpinningWheelView: View {

    // MARK: - Per-question state

    @AppStorage("wheel.question") private var question: String = ""
    /// Newline-separated user customisations. Empty = use locale-aware defaults.
    @AppStorage("wheel.options")  private var optionsRaw: String = ""

    @Environment(\.locale) private var locale
    @FocusState private var questionFocused: Bool
    @State private var showingSettings = false

    // MARK: - Spin state

    @State private var rotation: Double = 0
    @State private var spinning: Bool = false
    @State private var winnerIndex: Int? = nil
    @State private var revealVisible: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                questionCard
                settingsCard
                stage
                if let idx = winnerIndex, revealVisible {
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
            WheelSettingsSheet(optionsRaw: $optionsRaw)
                .presentationDetents([.medium, .large])
        }
    }

    /// User customisations if present; otherwise the locale-aware defaults.
    private var effectiveOptionsRaw: String {
        optionsRaw.isEmpty
            ? String.appLocalized("wheel.default.options", locale: locale)
            : optionsRaw
    }

    private var options: [String] {
        effectiveOptionsRaw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Sub-views

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("wheel.question.label")
                .font(Theme.body(13, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("wheel.question.placeholder", text: $question, axis: .vertical)
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
                    Text("wheel.settings.title")
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
        ZStack(alignment: .top) {
            WheelView(options: options)
                .rotationEffect(.degrees(rotation))
                .frame(width: 300, height: 300)
                .padding(.top, 18)

            // Pointer at top, pointing into the wheel.
            PointerShape()
                .fill(Theme.cinnabarDeep)
                .overlay(PointerShape().stroke(Theme.gold, lineWidth: 1.4))
                .frame(width: 28, height: 36)
                .shadow(color: Theme.woodShadow.opacity(0.35), radius: 3, x: 0, y: 2)
                .offset(y: 0)
        }
        .frame(height: 340)
    }

    private func revealCard(index: Int) -> some View {
        let label = options.indices.contains(index) ? options[index] : "—"
        return VStack(spacing: 6) {
            Text("wheel.reveal.title")
                .font(Theme.body(12, weight: .semibold))
                .foregroundStyle(Theme.inkQuiet)
                .textCase(.uppercase)
                .tracking(0.8)
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
        Button { performSpin() } label: {
            HStack(spacing: 10) {
                Image(systemName: spinning ? "hourglass" : "arrow.triangle.2.circlepath")
                Text(spinning
                     ? "wheel.action.spinning"
                     : (winnerIndex == nil ? "wheel.action.spin" : "wheel.action.again"))
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
        .disabled(spinning || options.count < 2)
        .opacity(spinning ? 0.7 : (options.count < 2 ? 0.5 : 1))
    }

    // MARK: - Spin

    private func performSpin() {
        let count = options.count
        guard count >= 2 else { return }
        questionFocused = false

        withAnimation(.easeIn(duration: 0.15)) { revealVisible = false }

        let winner = Int.random(in: 0..<count)
        let wedgeSize = 360.0 / Double(count)
        // Wheel wedges are drawn starting at top (12 o'clock) going CW.
        // After rotating the wheel by R°, wedge i's center sits at i*Δ + Δ/2 + R (CW from top).
        // We want that to equal 0 mod 360 for the winner.
        let targetCenter = Double(winner) * wedgeSize + wedgeSize / 2
        let baseSpins = Double(Int.random(in: 5...7)) * 360.0
        let jitter = Double.random(in: -wedgeSize * 0.25 ... wedgeSize * 0.25)
        let target = rotation + baseSpins + (360 - targetCenter.truncatingRemainder(dividingBy: 360)) + jitter

        spinning = true
        withAnimation(.timingCurve(0.18, 0.85, 0.30, 1.0, duration: 2.6)) {
            rotation = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            spinning = false
            winnerIndex = winner
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                revealVisible = true
            }
        }
    }
}

// MARK: - WheelView (wedges + labels)

private struct WheelView: View {
    let options: [String]

    private let palette: [Color] = [
        Theme.cinnabar,
        Theme.gold,
        Theme.parchmentDim,
        Theme.woodMid,
        Color(red: 0.55, green: 0.20, blue: 0.30) // muted maroon for adjacency
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            let n = max(options.count, 1)
            let wedge = 360.0 / Double(n)

            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    WedgePath(startDegrees: Double(i) * wedge - 90,
                              endDegrees: Double(i + 1) * wedge - 90,
                              center: center, radius: radius)
                        .fill(palette[i % palette.count])
                        .overlay(
                            WedgePath(startDegrees: Double(i) * wedge - 90,
                                      endDegrees: Double(i + 1) * wedge - 90,
                                      center: center, radius: radius)
                                .stroke(Theme.gold, lineWidth: 1.2)
                        )

                    // Wedge label — rotated so it reads radially.
                    if options.indices.contains(i) {
                        let midDeg = Double(i) * wedge + wedge / 2 - 90
                        Text(options[i])
                            .font(Theme.headlineSerif(15, weight: .semibold))
                            .foregroundStyle(textColor(for: i))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: radius * 0.65)
                            .multilineTextAlignment(.center)
                            .rotationEffect(.degrees(midDeg + 90))
                            .position(
                                x: center.x + cos(midDeg * .pi / 180) * radius * 0.62,
                                y: center.y + sin(midDeg * .pi / 180) * radius * 0.62
                            )
                    }
                }

                // Outer rim
                Circle()
                    .stroke(Theme.cinnabarDeep, lineWidth: 4)
                    .frame(width: size, height: size)

                // Center hub
                Circle()
                    .fill(
                        RadialGradient(colors: [Theme.gold, Theme.goldDeep],
                                       center: .center, startRadius: 4, endRadius: 30)
                    )
                    .overlay(Circle().stroke(Theme.cinnabarDeep, lineWidth: 1.4))
                    .frame(width: 46, height: 46)
                    .position(center)
            }
        }
        .shadow(color: Theme.woodShadow.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    private func textColor(for i: Int) -> Color {
        let fill = palette[i % palette.count]
        // Hand-tuned: cinnabar / wood / maroon → cream text; gold / parchmentDim → ink.
        switch i % palette.count {
        case 1, 2: return Theme.ink
        default:   return Color(red: 0.99, green: 0.95, blue: 0.86)
        }
    }
}

private struct WedgePath: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: center)
        p.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

private struct PointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))     // tip
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))  // top-left
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))  // top-right
        p.closeSubpath()
        return p
    }
}

// MARK: - Settings

private struct WheelSettingsSheet: View {
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
                    Text("wheel.settings.list_header")
                } footer: {
                    Text("wheel.settings.list_footer")
                }
            }
            .navigationTitle("wheel.settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") {
                        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        let localeDefault = String.appLocalized("wheel.default.options", locale: locale)
                        optionsRaw = (trimmed.isEmpty || draft == localeDefault) ? "" : draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = optionsRaw.isEmpty
                    ? String.appLocalized("wheel.default.options", locale: locale)
                    : optionsRaw
            }
        }
    }
}
