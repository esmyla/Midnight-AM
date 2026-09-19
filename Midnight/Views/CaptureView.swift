import SwiftUI

/// The 2 AM screen. One text box, one button, under 20 seconds to a locked commitment.
struct CaptureView: View {
    @EnvironmentObject var engine: CommitmentEngine
    @State private var prompt = ""
    @State private var parsing = false
    @State private var phraseIndex = 0
    @State private var draft: Commitment?
    @State private var clarifying: String?
    @State private var showHistory = false
    @FocusState private var focused: Bool

    private let examples: [(String, String)] = [
        ("LeetCode before TikTok", "Tomorrow, block TikTok, Instagram, and YouTube until I finish two LeetCode problems."),
        ("Gym before Instagram", "No Instagram tomorrow until I go to the gym."),
        ("Clean room, no games", "Block games until I clean my room."),
        ("Spanish before YouTube", "Don't let me open YouTube before noon unless I do 30 minutes of Spanish.")
    ]
    private let phrases = ["Reading your promise…", "Drafting the contract…", "Setting the terms…"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
            HStack {
                Text("MIDNIGHT").eyebrow()
                Spacer()
                IconButton(system: "clock.arrow.circlepath") { showHistory = true }
            }

            if let t = engine.interceptedAt, Date().timeIntervalSince(t) < 8, engine.penalty != nil {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill").font(.title3.weight(.bold))
                    Text("Nice try. You gave up, remember?")
                        .font(.system(.headline))
                    Spacer()
                }
                .foregroundStyle(.black.opacity(0.85))
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.amber))
                .padding(.top, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let p = engine.penalty {
                PenaltyBanner(commitment: p)
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 28)

            Text(greeting)
                .display(42)
                .padding(.bottom, 8)
            Text("Tell tomorrow's you what to do.\nThey don't get a vote.")
                .font(.system(.title3))
                .foregroundStyle(Theme.text2)
                .padding(.bottom, 26)

            TextField("Tomorrow, block TikTok until I…", text: $prompt, axis: .vertical)
                .lineLimit(2...6)
                .font(.system(.title3))
                .focused($focused)
                .submitLabel(.done)
                .disabled(parsing)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(focused ? Theme.accent.opacity(0.7) : Theme.stroke, lineWidth: 1.5))
                .shadow(color: focused ? Theme.accent.opacity(0.28) : .clear, radius: 24, y: 6)
                .animation(.easeOut(duration: 0.25), value: focused)

            if let clarifying {
                Label(clarifying, systemImage: "questionmark.circle.fill")
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            }
            .padding(.horizontal, 22)

            FlowLayout(spacing: 8) {
                ForEach(examples, id: \.0) { short, full in
                    Button {
                        Haptics.tick()
                        withAnimation(.smooth) { prompt = full; clarifying = nil }
                        focused = true
                    } label: { Chip(text: short, tint: Theme.text2, compact: true, uppercase: false) }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            Spacer()

            Group {
            Button(action: parse) {
                HStack(spacing: 10) {
                    if parsing {
                        ProgressView().tint(.black)
                        Text(phrases[phraseIndex]).contentTransition(.opacity)
                    } else {
                        Image(systemName: "lock.fill")
                        Text("Lock it in")
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: phraseIndex)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || parsing)

            if engine.promisesMade > 0 {
                Text("\(engine.promisesKept) of \(engine.promisesMade) promises kept")
                    .font(.system(.footnote))
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            }
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 22)
        .fullScreenCover(item: $draft) { d in
            ConfirmView(draft: d) {
                prompt = ""
                draft = nil
            }
        }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .onTapGesture { focused = false }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return "Still up?" }
        if h < 12 { return "Morning." }
        if h < 18 { return "Afternoon." }
        if h < 22 { return "Evening." }
        return "Motivated?"
    }

    private func parse() {
        focused = false
        Haptics.impact(.light)
        withAnimation(.smooth) { parsing = true; clarifying = nil }
        let text = prompt
        Task {
            let cycler = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(1400))
                    phraseIndex = (phraseIndex + 1) % phrases.count
                }
            }
            defer { cycler.cancel(); withAnimation(.smooth) { parsing = false }; phraseIndex = 0 }
            do {
                let parsed = try await CommitmentParser.parse(text)
                if let q = parsed.clarifying_question, !q.isEmpty {
                    Haptics.notify(.warning)
                    withAnimation(.smooth) { clarifying = q }
                    focused = true
                    return
                }
                Haptics.impact(.medium)
                draft = CommitmentParser.build(from: parsed, prompt: text)
            } catch {
                engine.lastError = error.localizedDescription
            }
        }
    }
}

/// Shown on the capture screen while an abandoned commitment is still serving its penalty.
struct PenaltyBanner: View {
    let commitment: Commitment
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HStack(spacing: 14) {
                Image(systemName: "hourglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 3) {
                    Text("You gave up on “\(commitment.title)”")
                        .font(.system(.subheadline).weight(.semibold))
                    Text("Apps stay locked for \(Clock.remaining(until: commitment.penaltyReleaseTime, from: ctx.date))")
                        .font(.system(.footnote))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.amber.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.amber.opacity(0.3), lineWidth: 1))
        }
    }
}
