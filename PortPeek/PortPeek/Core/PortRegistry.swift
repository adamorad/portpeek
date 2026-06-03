import Foundation
import Combine

@MainActor
final class PortRegistry: ObservableObject {
    @Published private(set) var entries: [PortEntry] = []
    @Published var monitoredPorts: [Int] {
        didSet { saveMonitoredPorts(); rebuildEntries() }
    }
    @Published var isMCPServerRunning: Bool = false

    let labelStore: LabelStore
    let reservationStore: ReservationStore

    @Published private(set) var lastScanned: Date?

    private let scanner = PortScanner(timeout: 0.5)
    private var scanTask: Task<Void, Never>?
    private var scanInterval: TimeInterval = 3.0
    private let portsKey = "portpeek.monitoredPorts"
    private let defaults: UserDefaults

    init(
        monitoredPorts: [Int] = PortEntry.defaultMonitoredPorts,
        labelStore: LabelStore = LabelStore(),
        reservationStore: ReservationStore = ReservationStore(),
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.labelStore = labelStore
        self.reservationStore = reservationStore
        let saved = defaults.array(forKey: portsKey) as? [Int]
        self.monitoredPorts = saved ?? monitoredPorts
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

    func addPort(_ port: Int) {
        guard !monitoredPorts.contains(port) else { return }
        monitoredPorts.append(port)
    }

    func removePort(_ port: Int) {
        monitoredPorts.removeAll { $0 == port }
    }

    // MARK: - Scanning

    func startScanning(interval: TimeInterval = 3.0) {
        scanInterval = interval
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performScan()
                try? await Task.sleep(nanoseconds: UInt64((self?.scanInterval ?? 3) * 1_000_000_000))
            }
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Private

    private func performScan() async {
        let ports = monitoredPorts
        let open = await scanner.probePorts(ports)
        lastScanned = Date()
        reservationStore.pruneExpired()
        applyOpenPorts(open)
    }

    private func applyOpenPorts(_ open: Set<Int>) {
        entries = monitoredPorts.map { port in
            let status: PortStatus
            if open.contains(port) {
                status = .listening
            } else if let r = reservationStore.reservation(for: port) {
                status = .reserved(project: r.project, expires: r.expires)
            } else {
                status = .available
            }
            return PortEntry(port: port, status: status, userLabel: labelStore.label(for: port))
        }
    }

    private func rebuildEntries() {
        entries = monitoredPorts.map { port in
            let status: PortStatus
            if let r = reservationStore.reservation(for: port) {
                status = .reserved(project: r.project, expires: r.expires)
            } else {
                status = .available
            }
            return PortEntry(port: port, status: status, userLabel: labelStore.label(for: port))
        }
    }

    private func saveMonitoredPorts() {
        defaults.set(monitoredPorts, forKey: portsKey)
    }
}
