import AppIntents
import Foundation

/// The action a Shortcuts automation runs when a blocked app opens.
/// Returns "LOCKED" or "UNLOCKED". The automation follows it with:
///   If [Lock Status] is LOCKED  ->  Open App: Midnight
/// Shortcuts opens the app itself, silently. No confirmation dialog, nothing to cancel.
struct LockStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Midnight Lock Status"
    static var description = IntentDescription(
        "Returns LOCKED while a Midnight commitment is active, otherwise UNLOCKED. Use with an If action and Open App."
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let locked = Store.enforced() != nil
        if locked { Store.markEnforced() }
        return .result(value: locked ? "LOCKED" : "UNLOCKED")
    }
}

/// Same check as a Boolean, for people who prefer it.
struct IsLockedIntent: AppIntent {
    static var title: LocalizedStringResource = "Is Midnight Locked"
    static var description = IntentDescription("True while a Midnight commitment is locking apps.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let locked = Store.enforced() != nil
        if locked { Store.markEnforced() }
        return .result(value: locked)
    }
}

struct MidnightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LockStatusIntent(),
            phrases: ["Get \(.applicationName) lock status"],
            shortTitle: "Lock status",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: IsLockedIntent(),
            phrases: ["Is \(.applicationName) locked"],
            shortTitle: "Is locked?",
            systemImageName: "questionmark.circle"
        )
    }
}
