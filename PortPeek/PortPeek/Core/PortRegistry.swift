import Foundation
import Combine

@MainActor
final class PortRegistry: ObservableObject {
    // Only contains ports that are listening or reserved — never the full 65k range.
    @Published private(set) var entries: [PortEntry] = []
    @Published var isMCPServerRunning: Bool = false
    @Published private(set) var lastScanned: Date?

    let labelStore: LabelStore
    let reservationStore: ReservationStore

    private let scanner = PortScanner()
    private var scanTask: Task<Void, Never>?
    private var scanInterval: TimeInterval = 15.0

    init(
        labelStore: LabelStore = LabelStore(),
        reservationStore: ReservationStore = ReservationStore()
    ) {
        self.labelStore = labelStore
        self.reservationStore = reservationStore
        rebuildEntries()
    }

    // MARK: - Public API

    func setLabel(_ label: String, for port: Int) {
        labelStore.setLabel(label, for: port)
        rebuildEntries()
    }

    func reserve(port: Int, project: String, ttlMinutes: Int) throws {
        try reservationStore.reserve(port: port, project: project, ttl: TimeInterval(ttlMinutes * 60))
        rebuildEntries()
    }

    func release(port: Int) {
        reservationStore.release(port: port)
        rebuildEntries()
    }

    // MARK: - Scanning

    func startScanning(interval: TimeInterval = 15.0) {
        scanInterval = interval
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performScan()
                try? await Task.sleep(nanoseconds: UInt64((self?.scanInterval ?? 15) * 1_000_000_000))
            }
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Private

    private func performScan() async {
        let open = await scanner.probePorts(PortEntry.portsToScan)
        lastScanned = Date()
        reservationStore.pruneExpired()
        applyOpenPorts(open)
    }

    private func applyOpenPorts(_ open: Set<Int>) {
        var result: [PortEntry] = []
        for port in open {
            result.append(PortEntry(port: port, status: .listening, userLabel: labelStore.label(for: port)))
        }
        for (port, r) in reservationStore.reservations where !open.contains(port) {
            result.append(PortEntry(port: port, status: .reserved(project: r.project, expires: r.expires), userLabel: labelStore.label(for: port)))
        }
        entries = result.sorted { $0.port < $1.port }
    }

    private func rebuildEntries() {
        entries = reservationStore.reservations.map { (port, r) in
            PortEntry(port: port, status: .reserved(project: r.project, expires: r.expires), userLabel: labelStore.label(for: port))
        }.sorted { $0.port < $1.port }
    }
}
