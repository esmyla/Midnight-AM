import SwiftUI

/// The morning-after screen: a draining ring, the promise, and two exits.
struct LockedView: View {
    @EnvironmentObject var engine: CommitmentEngine
    let commitment: Commitment

    @State private var showVerify = false
    @State private var showGiveUp = false
    @State private var showSetup = false
    @State private var showHistory = false
    @State private var showIntercept = false
    @State private var appeared = false

    /// Derived from the clock, not stored status, so the screen flips the second the start time passes.
    private func isScheduled(_ now: Date) -> Bool { now < commitment.activationTime }
    private func phaseKey(_ now: Date) -> Int {
        if now < commitment.activationTime { return 0 }
        if now < commitment.deadline { return 1 }
        return 2
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = ctx.date
            let scheduled = isScheduled(now)
            let tint = scheduled ? Theme.accent2 : Theme.accent
            VStack(spacing: 0) {
                HStack {
                    StatusPill(text: scheduled ? "Scheduled" : "Locked", tint: tint, pulsing: !scheduled)
                    Spacer()
                    IconButton(system: "clock.arrow.circlepath") { showHistory = true }
                }

                if showIntercept {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill").font(.title3.weight(.bold))
                        Text("Nice try. Do the thing first.")
                            .font(.system(.headline))
                        Spacer()
                    }
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.amber))
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                ZStack {
                    TimeRing(progress: ringProgress(now), tint: tint)
                        .frame(width: 300, height: 300)
                        .scaleEffect(appeared ? 1 : 0.85)
                        .opacity(appeared ? 1 : 0)
                    VStack(spacing: 8) {
                        Text(scheduled ? "STARTS IN" : "TIME LEFT").eyebrow()
                        Text(Clock.remaining(until: scheduled ? commitment.activationTime : commitment.deadline, from: now))
                            .display(44)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy(duration: 0.3), value: now)
                        Text(scheduled
                             ? "locks \(Clock.day(commitment.activationTime)) at \(Clock.short(commitment.activationTime))"
                             : "deadline \(Clock.short(commitment.deadline))")
                            .font(.system(.footnote))
                            .foregroundStyle(Theme.text2)
                    }
                }
                .padding(.vertical, 28)

                Spacer()

                VStack(spacing: 14) {
                    Text(commitment.title)
                        .display(30)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if !commitment.blockedApps.isEmpty {
                        FlowLayout(spacing: 8, alignment: .center) {
                            ForEach(commitment.blockedApps, id: \.self) { app in
                                Chip(text: app, icon: "lock.fill", tint: tint.opacity(0.9))
                            }
                        }
                    }
                    if !Setup.isDone {
                        Button { showSetup = true } label: {
                            Label("Finish blocking setup", systemImage: "exclamationmark.shield.fill")
                                .font(.system(.caption).weight(.semibold))
                                .foregroundStyle(Theme.amber)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                Spacer()

                VStack(spacing: 6) {
                    if scheduled {
                        Button("Cancel before it starts") {
                            Haptics.impact(.light)
                            engine.cancelBeforeStart()
                        }
                        .buttonStyle(GhostButtonStyle())
                    } else {
                        Button {
                            Haptics.impact(.medium)
                            showVerify = true
                        } label: { Label("I did it", systemImage: "checkmark.seal.fill") }
                            .buttonStyle(PrimaryButtonStyle(tint: tint))
                        Button("Give up") { showGiveUp = true }
                            .buttonStyle(GhostButtonStyle(tint: Theme.text3))
                    }
                }
                .opacity(appeared ? 1 : 0)
            }
            .padding(22)
            .onChange(of: phaseKey(now)) { _, _ in
                Haptics.impact(.heavy)
                engine.refresh()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { appeared = true }
            handleIntercept()
        }
        .onChange(of: engine.interceptedAt) { _, _ in handleIntercept() }
        .sheet(isPresented: $showVerify) { VerifyView(commitment: commitment) }
        .sheet(isPresented: $showGiveUp) { GiveUpView(commitment: commitment) }
        .sheet(isPresented: $showSetup) { SetupView() }
        .sheet(isPresented: $showHistory) { HistoryView() }
    }

    /// Fraction of the current window remaining. Drains like a timer.
    private func ringProgress(_ now: Date) -> Double {
        let scheduled = isScheduled(now)
        let start = scheduled ? commitment.createdAt : commitment.activationTime
        let end = scheduled ? commitment.activationTime : commitment.deadline
        let total = max(1, end.timeIntervalSince(start))
        return max(0, min(1, end.timeIntervalSince(now) / total))
    }

    private func handleIntercept() {
        guard let t = engine.interceptedAt, Date().timeIntervalSince(t) < 8 else { return }
        Haptics.notify(.warning)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { showIntercept = true }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.35)) { showIntercept = false }
        }
    }
}
