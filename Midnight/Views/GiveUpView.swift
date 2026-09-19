import SwiftUI

/// The escape hatch that costs something: a 10-second wait, a typed reason,
/// and the apps stay locked until the penalty release time anyway.
struct GiveUpView: View {
    @EnvironmentObject var engine: CommitmentEngine
    @Environment(\.dismiss) private var dismiss
    let commitment: Commitment

    @State private var reason = ""
    @State private var secondsLeft = 10
    @FocusState private var focused: Bool

    private var releaseText: String { Clock.short(commitment.penaltyReleaseTime) }
    private var canQuit: Bool { secondsLeft == 0 && reason.trimmingCharacters(in: .whitespaces).count >= 3 }

    var body: some View {
        ZStack {
            Color.clear.background(MidnightBackground(tint: Theme.rose))
            VStack(alignment: .leading, spacing: 18) {
                HStack { IconButton(system: "xmark") { dismiss() }; Spacer() }

                Text("You can give up.")
                    .display(36)
                Text("Apps stay locked until **\(releaseText)**.")
                    .font(.system(.body))
                    .foregroundStyle(Theme.text2)

                VStack(alignment: .leading, spacing: 10) {
                    Text("WHY ARE YOU QUITTING?").eyebrow()
                    TextField("Be honest. Future you reads this.", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(.body))
                        .focused($focused)
                }
                .glass(18)

                Spacer()

                Button("I'll do it") { Haptics.impact(.light); dismiss() }
                    .buttonStyle(PrimaryButtonStyle())

                Button {
                    Haptics.notify(.warning)
                    engine.giveUp(reason: reason)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text(secondsLeft > 0 ? "Give up" : "Give up. Stay locked until \(releaseText)")
                        if secondsLeft > 0 {
                            Text("\(secondsLeft)")
                                .monospacedDigit()
                                .contentTransition(.numericText(countsDown: true))
                                .opacity(0.6)
                        }
                    }
                }
                .buttonStyle(OutlineButtonStyle(tint: Theme.rose))
                .disabled(!canQuit)
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .task {
            while secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.snappy) { secondsLeft -= 1 }
            }
        }
    }
}
