import SwiftUI

/// Promises made, promises kept. A record, not a streak.
struct HistoryView: View {
    @EnvironmentObject var engine: CommitmentEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.clear.background(MidnightBackground(tint: Theme.accent))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { IconButton(system: "xmark") { dismiss() }; Spacer() }
                    Text("Your record.")
                        .display(36)

                    HStack(spacing: 10) {
                        StatTile(value: "\(engine.promisesMade)", label: "Made")
                        StatTile(value: "\(engine.promisesKept)", label: "Kept", tint: Theme.mint)
                        StatTile(value: "\(engine.keepRate)%", label: "Rate", tint: Theme.accent)
                    }

                    if engine.all.isEmpty {
                        Text("Nothing yet. Make a promise tonight.")
                            .font(.system(.body))
                            .foregroundStyle(Theme.text3)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }

                    ForEach(engine.all) { c in
                        HStack(alignment: .top, spacing: 14) {
                            Circle().fill(color(c.status)).frame(width: 8, height: 8).padding(.top, 7)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.title).font(.system(.headline))
                                Text("\(c.activationTime.formatted(date: .abbreviated, time: .shortened)) · \(c.status.label)")
                                    .font(.system(.caption))
                                    .foregroundStyle(Theme.text2)
                                if let note = c.verificationNote, !note.isEmpty {
                                    Text(note).font(.system(.caption))
                                        .foregroundStyle(Theme.text3).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .glass(16)
                    }

                    #if DEBUG
                    Button("Reset everything (debug build only)") {
                        engine.debugReset()
                        dismiss()
                    }
                    .buttonStyle(GhostButtonStyle(tint: Theme.rose.opacity(0.7)))
                    .padding(.top, 20)
                    #endif
                }
                .padding(22)
            }
            TopScrim()
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }

    private func color(_ s: CommitmentStatus) -> Color {
        switch s {
        case .completed: return Theme.mint
        case .failed: return Theme.rose
        case .abandoned: return Theme.amber
        default: return Theme.accent
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = .white
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .display(30)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label.uppercased()).eyebrow()
        }
        .frame(maxWidth: .infinity)
        .glass(16)
    }
}
