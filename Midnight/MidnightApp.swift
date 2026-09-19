import SwiftUI

@main
struct MidnightApp: App {
    @StateObject private var engine = CommitmentEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { url in
                    if url == Store.lockedURL { engine.interceptedAt = Date() }
                    engine.refresh()
                }

        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { engine.refresh() }
        }
    }
}
