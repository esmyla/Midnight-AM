import Foundation
import Combine
import UserNotifications

/// Owns the live commitment lifecycle: lock, activate, verify, release, give up.
/// Enforcement itself happens in EnforceCommitmentIntent via Shortcuts automations.
@MainActor
final class CommitmentEngine: ObservableObject {
    @Published private(set) var all: [Commitment] = []
    @Published var lastError: String?
    /// Set when Shortcuts pulled the user out of a blocked app.
    @Published var interceptedAt: Date?
    /// Set when a commitment is verified complete; drives the unlock celebration.
    @Published var celebration: Commitment?

    var live: Commitment? { all.first { $0.status.isLive } }
    var enforced: Commitment? { all.first { $0.isLocked() } }
    /// An abandoned commitment still serving its penalty.
    var penalty: Commitment? { all.first { $0.status == .abandoned && $0.isLocked() } }

    init() { refresh() }

    func refresh() {
        all = Store.loadAll()
        reconcile()
        // The Shortcuts action stamps the moment it blocked an app; a foreground right after is an intercept.
        if let t = Store.lastEnforcedAt, Date().timeIntervalSince(t) < 15, interceptedAt != t {
            interceptedAt = t
        }
    }

    /// Catch up on time-based transitions for display. isLocked() is computed from
    /// timestamps, so enforcement is correct even if this never runs.
    private func reconcile() {
        guard var c = live else { return }
        let now = Date()
        var changed = false
        if c.status == .scheduled, now >= c.activationTime { c.status = .active; changed = true }
        if (c.status == .active || c.status == .awaitingVerification), now >= c.deadline {
            c.status = .failed; changed = true
        }
        if changed { persist(c) }
    }

    private func persist(_ c: Commitment) {
        Store.upsert(c)
        all = Store.loadAll()
    }

    // MARK: Lock

    func lock(_ draft: Commitment) async -> Bool {
        var c = draft
        c.status = c.activationTime <= Date() ? .active : .scheduled
        persist(c)
        await scheduleNotifications(for: c)
        return true
    }

    // MARK: Completion

    func markAwaitingVerification() {
        guard var c = live else { return }
        c.status = .awaitingVerification
        persist(c)
    }

    func complete(note: String?) {
        guard var c = live else { return }
        c.status = .completed
        c.completedAt = Date()
        c.verificationNote = note
        persist(c)
        cancelNotifications()
        celebration = c
    }

    func verificationFailed() {
        guard var c = live, c.status == .awaitingVerification else { return }
        c.status = .active
        persist(c)
    }

    // MARK: Give up

    /// The deliberately painful exit: the lock stays on until the penalty release time.
    func giveUp(reason: String) {
        guard var c = live else { return }
        c.status = .abandoned
        c.abandonedAt = Date()
        c.verificationNote = reason
        c.penaltyReleaseTime = max(c.penaltyReleaseTime, Date().addingTimeInterval(15 * 60))
        persist(c)
        cancelNotifications()
    }

    /// Only for a scheduled commitment that has not started yet. Still recorded as abandoned.
    func cancelBeforeStart() {
        guard var c = live, c.status == .scheduled else { return }
        c.status = .abandoned
        c.abandonedAt = Date()
        c.penaltyReleaseTime = Date()
        persist(c)
        cancelNotifications()
    }

    // MARK: Notifications

    /// Ask once, ahead of the lock moment, so the lock animation is never interrupted.
    func requestNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    private func scheduleNotifications(for c: Commitment) async {
        let center = UNUserNotificationCenter.current()
        cancelNotifications()
        let apps = c.blockedApps.isEmpty ? "Your apps are" : c.blockedApps.joined(separator: ", ") + (c.blockedApps.count == 1 ? " is" : " are")
        if c.activationTime > Date() {
            let n = UNMutableNotificationContent()
            n.title = "It's on."
            n.body = "\(apps) locked until you \(c.taskDescription). You asked for this."
            n.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: c.activationTime),
                repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "midnight.activate", content: n, trigger: trigger))
        }
        let reminderTime = c.deadline.addingTimeInterval(-2 * 3600)
        if reminderTime > Date() {
            let n = UNMutableNotificationContent()
            n.title = "Two hours left."
            n.body = "\(c.title). Finish it, verify, and unlock."
            n.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
                repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "midnight.reminder", content: n, trigger: trigger))
        }
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["midnight.activate", "midnight.reminder"])
    }

    #if DEBUG
    /// Development only: wipe everything, including an active penalty.
    func debugReset() {
        Store.saveAll([])
        all = []
        cancelNotifications()
    }
    #endif

    // MARK: Stats

    var promisesMade: Int { all.filter { !$0.status.isLive }.count }
    var promisesKept: Int { all.filter { $0.status == .completed }.count }
    var keepRate: Int { promisesMade == 0 ? 0 : Int((Double(promisesKept) / Double(promisesMade) * 100).rounded()) }
}
