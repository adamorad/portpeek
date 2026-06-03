import Foundation
import Combine

struct Reservation: Codable {
    let port: Int
    let project: String
    let expires: Date

    var isExpired: Bool { expires < Date() }
    var secondsRemaining: Int { max(0, Int(expires.timeIntervalSinceNow)) }
}

enum ReservationError: Error {
    case alreadyReserved(port: Int, by: String)
}

final class ReservationStore: ObservableObject {
    @Published private(set) var reservations: [Int: Reservation] = [:]

    private let defaults: UserDefaults
    private let key = "portpeek.reservations"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        pruneExpired()
    }

    func reserve(port: Int, project: String, ttl: TimeInterval) throws {
        pruneExpired()
        if let existing = reservations[port], !existing.isExpired {
            throw ReservationError.alreadyReserved(port: port, by: existing.project)
        }
        reservations[port] = Reservation(port: port, project: project, expires: Date().addingTimeInterval(ttl))
        save()
    }

    func release(port: Int) {
        reservations.removeValue(forKey: port)
        save()
    }

    func isReserved(_ port: Int) -> Bool {
        guard let r = reservations[port] else { return false }
        return !r.isExpired
    }

    func reservation(for port: Int) -> Reservation? {
        guard let r = reservations[port], !r.isExpired else { return nil }
        return r
    }

    func pruneExpired() {
        let pruned = reservations.filter { !$0.value.isExpired }
        guard pruned.count != reservations.count else { return }
        reservations = pruned
        save()
    }

    private func load() {
        // Uses binary JSON (data(forKey:)) rather than dictionary(forKey:) because
        // UserDefaults string-keyed dictionaries cannot round-trip Int keys without loss.
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Int: Reservation].self, from: data)
        else { return }
        reservations = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reservations) else { return }
        defaults.set(data, forKey: key)
    }
}
