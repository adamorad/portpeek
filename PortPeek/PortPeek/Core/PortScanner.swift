import Foundation
import Network
import os

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
        guard port >= 1, port <= 65535,
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            let conn = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
            // Both stateUpdateHandler and asyncAfter are dispatched on this serial queue,
            // so reads/writes to didResume are serialized without additional locking.
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
