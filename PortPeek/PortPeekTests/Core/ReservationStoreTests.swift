import XCTest
@testable import PortPeek

final class ReservationStoreTests: XCTestCase {
    var store: ReservationStore!
    var suiteName: String!

    override func setUp() {
        suiteName = "test.reservations.\(UUID().uuidString)"
        store = ReservationStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func test_reserve_marksPortAsReserved() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: 300)
        XCTAssertTrue(store.isReserved(3000))
    }

    func test_release_clearsReservation() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: 300)
        store.release(port: 3000)
        XCTAssertFalse(store.isReserved(3000))
    }

    func test_reservation_includesProjectAndExpiry() throws {
        let before = Date()
        try store.reserve(port: 3000, project: "ideas-v2", ttl: 300)
        let r = try XCTUnwrap(store.reservation(for: 3000))
        XCTAssertEqual(r.project, "ideas-v2")
        XCTAssertGreaterThan(r.expires, before.addingTimeInterval(299))
    }

    func test_expiredReservation_isNotReserved() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: -1)
        XCTAssertFalse(store.isReserved(3000))
        XCTAssertNil(store.reservation(for: 3000))
    }

    func test_pruneExpired_removesEntryFromDictionary() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: -1)
        XCTAssertNotNil(store.reservations[3000], "entry should exist before prune")
        store.pruneExpired()
        XCTAssertNil(store.reservations[3000], "entry should be removed after prune")
    }

    func test_reservingAlreadyReservedPort_throws() throws {
        try store.reserve(port: 3000, project: "myapp", ttl: 300)
        XCTAssertThrowsError(try store.reserve(port: 3000, project: "other", ttl: 300))
    }
}
