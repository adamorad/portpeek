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

    func reserve(port: Int, project: String, ttl: TimeInterval) throws {
        pruneExpired()
        if let existing = reservations[port], !existing.isExpired {
            throw ReservationError.alreadyReserved(port: port, by: existing.project)
        }
        reservations[port] = Reservation(port: port, project: project, expires: Date().addingTimeInterval(ttl))
    }

    func release(port: Int) {
        reservations.removeValue(forKey: port)
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
        reservations = reservations.filter { !$0.value.isExpired }
    }
}
