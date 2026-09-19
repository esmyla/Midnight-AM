import SwiftUI

// MARK: - Palette: matte black, brass, one red. Nothing pastel.

enum Theme {
    static let accent  = Color(red: 0.91, green: 0.66, blue: 0.26)   // brass
    static let accent2 = Color(red: 0.72, green: 0.75, blue: 0.80)   // steel (scheduled)
    static let amber   = Color(red: 0.96, green: 0.50, blue: 0.20)   // hot: penalty, warnings
    static let rose    = Color(red: 0.88, green: 0.24, blue: 0.22)   // give up
    static let mint    = Color(red: 0.64, green: 0.82, blue: 0.58)   // kept, muted
    static let bg      = Color(red: 0.043, green: 0.043, blue: 0.051)
    static let card    = Color(red: 0.078, green: 0.078, blue: 0.090)
    static let stroke  = Color.white.opacity(0.09)
    static let text2   = Color.white.opacity(0.60)
    static let text3   = Color.white.opacity(0.36)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.98, green: 0.82, blue: 0.52), accent], startPoint: .top, endPoint: .bottom)
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Backdrop: black, faint state tint, grain, vignette. Static and cheap.

struct MidnightBackground: View {
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg
                LinearGradient(colors: [Color.white.opacity(0.045), .clear],
                               startPoint: .topLeading, endPoint: .init(x: 0.5, y: 0.55))
                RadialGradient(colors: [tint.opacity(0.14), .clear],
                               center: UnitPoint(x: 0.5, y: -0.05),
                               startRadius: 0, endRadius: geo.size.width * 0.95)
                Grain()
                RadialGradient(colors: [.clear, Color.black.opacity(0.5)],
                               center: .center,
                               startRadius: geo.size.width * 0.35, endRadius: geo.size.height * 0.72)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: tint)
    }
}

private struct Grain: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 11)
            for _ in 0..<2200 {
                let x = rng.next() * size.width, y = rng.next() * size.height
                let a = 0.015 + rng.next() * 0.06
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}

/// Fades scrolling content out under the status bar.
struct TopScrim: View {
    var body: some View {
        VStack {
            LinearGradient(colors: [Theme.bg, Theme.bg.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 90)
                .ignoresSafeArea(edges: .top)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Type

extension View {
    /// Heavy, tight display type for headlines.
    func display(_ size: CGFloat) -> some View {
        self.font(.system(size: size, weight: .heavy)).kerning(-size * 0.025)
    }
    /// Small uppercase label with wide tracking.
    func eyebrow() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .kerning(2.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.text3)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, tint: tint)
    }
    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .heavy))
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.black.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint))
                .opacity(isEnabled ? 1 : 0.3)
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .brightness(configuration.isPressed ? -0.08 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }
}

/// Outlined, low-emphasis action. Used for the exit nobody should want to take.
struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = Theme.text2
    func makeBody(configuration: Configuration) -> some View {
        OutlineButtonBody(configuration: configuration, tint: tint)
    }
    private struct OutlineButtonBody: View {
        let configuration: Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .heavy))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.5), lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.35)
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.text2
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 48)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let system: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.text2)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Surfaces

struct Panel: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

extension View {
    func glass(_ padding: CGFloat = 18) -> some View { modifier(Panel(padding: padding)) }
}

/// Uppercase tag. Used for locked apps and status.
struct Chip: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Theme.accent
    var compact = false
    var uppercase = true
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
            Text(text).lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(tint.opacity(0.55))
            }
        }
        .font(.system(size: compact ? 12 : 12, weight: uppercase ? .bold : .semibold))
        .kerning(uppercase ? 1.1 : 0)
        .textCase(uppercase ? .uppercase : nil)
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, compact ? 7 : 8)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }
}

struct StatusPill: View {
    let text: String
    var tint: Color = Theme.accent
    var pulsing = false
    @State private var on = false
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(tint).frame(width: 6, height: 6)
                .opacity(on ? 1 : 0.35)
                .animation(pulsing ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: on)
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .kerning(2.2)
                .textCase(.uppercase)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        .onAppear { on = true }
    }
}

// MARK: - Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rows: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.width, x > 0 { rows.append([]); x = 0 }
            rows[rows.count - 1].append((s, sz))
            x += sz.width + spacing
        }
        var y = bounds.minY
        for row in rows {
            let rowW = row.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, row.count - 1))
            let rowH = row.map { $1.height }.max() ?? 0
            var px: CGFloat
            switch alignment {
            case .center: px = bounds.minX + (bounds.width - rowW) / 2
            case .trailing: px = bounds.maxX - rowW
            default: px = bounds.minX
            }
            for (s, sz) in row {
                s.place(at: CGPoint(x: px, y: y), proposal: .unspecified)
                px += sz.width + spacing
            }
            y += rowH + spacing
        }
    }
}

// MARK: - Time

enum Clock {
    static func remaining(until end: Date, from now: Date) -> String {
        let s = max(0, Int(end.timeIntervalSince(now).rounded(.down)))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60, sec = s % 60
        if d > 0 { return String(format: "%dd %02d:%02d:%02d", d, h, m, sec) }
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }
    static func short(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }
    static func day(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "today" }
        if cal.isDateInTomorrow(d) { return "tomorrow" }
        return d.formatted(.dateTime.weekday(.wide))
    }
}

/// Instrument-style ring: tick marks around a solid arc.
struct TimeRing: View {
    var progress: Double
    var tint: Color = Theme.accent
    var lineWidth: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            ZStack {
                ForEach(0..<60, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 5 == 0 ? 0.28 : 0.12))
                        .frame(width: 1.5, height: i % 5 == 0 ? 10 : 5)
                        .offset(y: -(r - 30))
                        .rotationEffect(.degrees(Double(i) * 6))
                }
                Circle().stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.003, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Overlays

struct LockInOverlay: View {
    var onDone: () -> Void
    @State private var phase = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .scaleEffect(phase >= 1 ? 1 : 0.7)
                    Image(systemName: phase >= 2 ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(Theme.accentGradient)
                        .contentTransition(.symbolEffect(.replace))
                        .scaleEffect(phase >= 1 ? 1 : 0.6)
                }
                Text("Locked in.")
                    .display(40)
                    .opacity(phase >= 2 ? 1 : 0).offset(y: phase >= 2 ? 0 : 8)
                Text("SEE YOU IN THE MORNING").eyebrow()
                    .opacity(phase >= 3 ? 1 : 0)
            }
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = 1 }
            try? await Task.sleep(for: .milliseconds(380))
            Haptics.impact(.heavy)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { phase = 2 }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.3)) { phase = 3 }
            try? await Task.sleep(for: .milliseconds(1200))
            onDone()
        }
    }
}

struct UnlockOverlay: View {
    let commitment: Commitment
    let kept: Int
    let made: Int
    var onDone: () -> Void
    @State private var phase = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
                            .frame(width: 160, height: 160)
                            .scaleEffect(phase >= 1 ? 1.3 + Double(i) * 0.35 : 0.9)
                            .opacity(phase >= 1 ? 0 : 0.8)
                            .animation(.easeOut(duration: 1.0).delay(Double(i) * 0.1), value: phase)
                    }
                    Image(systemName: phase >= 1 ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(Theme.accentGradient)
                        .contentTransition(.symbolEffect(.replace))
                }
                Text("Promise kept.")
                    .display(40)
                    .opacity(phase >= 2 ? 1 : 0).offset(y: phase >= 2 ? 0 : 8)
                Text(commitment.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .opacity(phase >= 2 ? 1 : 0)
                Text("\(kept) OF \(made) KEPT")
                    .font(.system(size: 12, weight: .heavy)).kerning(2.2)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 8)
                    .opacity(phase >= 3 ? 1 : 0)

                Button("Unlocked. Continue") { onDone() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 28)
                    .opacity(phase >= 3 ? 1 : 0)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            Haptics.notify(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = 1 }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.3)) { phase = 2 }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.3)) { phase = 3 }
        }
    }
}
