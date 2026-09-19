import Foundation

/// Persistence. Plain UserDefaults; App Groups are not available on a free team and the
/// App Intent runs inside the app's own process, so nothing else needs to read this.
enum Store {
    private static let key = "commitments.v2"
    static let lockedURL = URL(string: "midnight://locked")!

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    static func loadAll() -> [Commitment] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? decoder.decode([Commitment].self, from: data) else { return [] }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    static func saveAll(_ list: [Commitment]) {
        if let data = try? encoder.encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }

    static func upsert(_ c: Commitment) {
        var list = loadAll()
        if let i = list.firstIndex(where: { $0.id == c.id }) { list[i] = c } else { list.insert(c, at: 0) }
        saveAll(list)
    }

    static func live() -> Commitment? { loadAll().first { $0.status.isLive } }

    /// Live commitment, or an abandoned one still serving its penalty.
    static func enforced(at now: Date = Date()) -> Commitment? {
        loadAll().first { $0.isLocked(at: now) }
    }

    private static let enforcedKey = "enforce.lastAt"
    /// Called by the Shortcuts action when it answers LOCKED. The app treats a foreground
    /// within a few seconds of this as "the user just got pulled out of a blocked app."
    static func markEnforced() { UserDefaults.standard.set(Date(), forKey: enforcedKey) }
    static var lastEnforcedAt: Date? { UserDefaults.standard.object(forKey: enforcedKey) as? Date }
}
