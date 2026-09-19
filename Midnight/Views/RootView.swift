import SwiftUI

struct RootView: View {
    @EnvironmentObject var engine: CommitmentEngine

    private var tint: Color {
        guard let live = engine.live else { return engine.penalty != nil ? Theme.amber : Theme.accent }
        return live.status == .scheduled ? Theme.accent2 : Theme.accent
    }

    var body: some View {
        ZStack {
            MidnightBackground(tint: tint)

            ZStack {
                if let live = engine.live {
                    LockedView(commitment: live)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.96))))
                } else {
                    CaptureView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.smooth(duration: 0.55), value: engine.live?.id)

            if let c = engine.celebration {
                UnlockOverlay(commitment: c, kept: engine.promisesKept, made: engine.promisesMade) {
                    withAnimation(.easeOut(duration: 0.35)) { engine.celebration = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { engine.lastError != nil },
            set: { if !$0 { engine.lastError = nil } })) {
            Button("OK") { engine.lastError = nil }
        } message: { Text(engine.lastError ?? "") }
    }
}
