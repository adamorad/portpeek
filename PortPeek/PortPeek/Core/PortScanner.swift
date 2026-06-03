import Foundation
import Network

final class PortScanner {
    let timeout: TimeInterval

    init(timeout: TimeInterval = 0.5) {
        self.timeout = timeout
    }

    func probePorts(_ ports: [Int]) async -> Set<Int> {
        await withTaskGroup(of: (Int, Bool).self) { group in
            for port in ports {
                group.addTask { [self] in
                    (port, await self.probePort(port))
                }
            }
            var open = Set<Int>()
            for await (port, isOpen) in group {
                if isOpen { open.insert(port) }
            }
            return open
        }
    }

    func probePort(_ port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
                continuation.resume(returning: false)
                return
            }
            let conn = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
            let queue = DispatchQueue(label: "portpeek.probe.\(port)")
            var didResume = false

            conn.stateUpdateHandler = { state in
                guard !didResume else { return }
                switch state {
                case .ready:
                    didResume = true
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    didResume = true
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + self.timeout) {
                guard !didResume else { return }
                didResume = true
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}
