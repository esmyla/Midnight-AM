import Foundation

enum CommitmentStatus: String, Codable {
    case scheduled
    case active
    case awaitingVerification
    case completed
    case failed
    case abandoned

    var isLive: Bool {
        switch self {
        case .scheduled, .active, .awaitingVerification: return true
        case .completed, .failed, .abandoned: return false
        }
    }

    var label: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .awaitingVerification: return "Verifying"
        case .completed: return "Kept"
        case .failed: return "Missed"
        case .abandoned: return "Gave up"
        }
    }
}

enum VerificationMethod: String, Codable, CaseIterable, Identifiable {
    case screenshot
    case photo
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .photo: return "Photo"
        case .manual: return "My word"
        }
    }
}

/// A promise the motivated user makes to their future self.
struct Commitment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// Exactly what the user typed or dictated.
    var prompt: String

    var title: String
    var taskDescription: String
    var quantity: Int?
    var unit: String?

    var activationTime: Date
    var deadline: Date

    /// Apps the user wants locked. Enforcement is a Shortcuts automation per app
    /// that asks Midnight "locked right now?" and pulls the user back here if so.
    var blockedApps: [String]

    var verification: VerificationMethod

    /// If the user gives up, the lock stays on until this moment.
    var penaltyReleaseTime: Date

    var status: CommitmentStatus = .scheduled
    var completedAt: Date?
    var abandonedAt: Date?
    var verificationNote: String?

    var quantityLine: String {
        if let quantity, let unit, !unit.isEmpty { return "\(quantity) \(unit)" }
        if let quantity { return "\(quantity)" }
        return ""
    }

    /// The single source of truth Shortcuts asks about. Computed from timestamps so it is
    /// correct even if the app has not run since the state changed.
    func isLocked(at now: Date = Date()) -> Bool {
        switch status {
        case .scheduled, .active, .awaitingVerification:
            return now >= activationTime && now < deadline
        case .abandoned:
            return now < penaltyReleaseTime
        case .completed, .failed:
            return false
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: Commitment, b: Commitment) -> Bool { a.id == b.id && a.status == b.status }
}
