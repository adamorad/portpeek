import Foundation
import Combine

@MainActor
final class PortRegistry: ObservableObject {
    /// Only listening and reserved ports — never the full monitored list.
    @Published private(set) var entries: [PortEntry] = []
    @Published var isMCPServerRunning: Bool = false
    @Published private(set) var lastScanned: Date?

    let labelStore: LabelStore
    let reservationStore: ReservationStore

    let scanner = PortScanner()
    private var scanTask: Task<Void, Never>?

    init(
        labelStore: LabelStore = LabelStore(),
        reservationStore: ReservationStore = ReservationStore()
    ) {
        self.labelStore = labelStore
        self.reservationStore = reservationStore
        rebuildFromReservations()
    }

    // MARK: - Public API

    func setLabel(_ label: String, for port: Int) {
        labelStore.setLabel(label, for: port)
        rebuildFromReservations()
    }

    func reserve(port: Int, project: String, ttlMinutes: Int) throws {
        try reservationStore.reserve(port: port, project: project, ttl: TimeInterval(ttlMinutes * 60))
        rebuildFromReservations()
    }

    func release(port: Int) {
        reservationStore.release(port: port)
        rebuildFromReservations()
    }

    // MARK: - Scanning

    func startScanning(interval: TimeInterval = 3.0) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scan()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Private

    private func scan() async {
        let open = await scanner.probePorts(PortEntry.monitoredPorts)
        lastScanned = Date()
        reservationStore.pruneExpired()

        var result: [PortEntry] = []
        for port in open {
            result.append(PortEntry(port: port, status: .listening, userLabel: labelStore.label(for: port)))
        }
        for (port, r) in reservationStore.reservations where !open.contains(port) {
            result.append(PortEntry(port: port, status: .reserved(project: r.project, expires: r.expires), userLabel: labelStore.label(for: port)))
        }
        entries = result.sorted { $0.port < $1.port }
    }

    private func rebuildFromReservations() {
        let reserved = reservationStore.reservations.map { (port, r) in
            PortEntry(port: port, status: .reserved(project: r.project, expires: r.expires), userLabel: labelStore.label(for: port))
        }.sorted { $0.port < $1.port }

        // Preserve any currently-listening entries, merge in reservations.
        let listening = entries.filter { $0.status == .listening }
        let listeningPorts = Set(listening.map { $0.port })
        let newReserved = reserved.filter { !listeningPorts.contains($0.port) }
        entries = (listening + newReserved).sorted { $0.port < $1.port }
    }
}
