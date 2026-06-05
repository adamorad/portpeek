import Foundation
import Network
import os

final class PortScanner {
    private let timeout: TimeInterval
    // One shared concurrent queue for all NWConnections.
    private let queue = DispatchQueue(label: "com.portpeek.scanner", attributes: .concurrent)

    init(timeout: TimeInterval = 0.2) {
        self.timeout = timeout
    }

    /// Probes all ports concurrently and returns the set that are listening.
    func probePorts(_ ports: [Int]) async -> Set<Int> {
        await withTaskGroup(of: (Int, Bool).self) { group in
            for port in ports {
                group.addTask { [self] in (port, await self.probePort(port)) }
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
            let didResume = OSAllocatedUnfairLock(initialState: false)

            let tryConsume: @Sendable () -> Bool = {
                didResume.withLock { flag -> Bool in
                    guard !flag else { return false }
                    flag = true; return true
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard tryConsume() else { return }
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    guard tryConsume() else { return }
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            conn.start(queue: self.queue)

            self.queue.asyncAfter(deadline: .now() + self.timeout) {
                guard tryConsume() else { return }
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}
