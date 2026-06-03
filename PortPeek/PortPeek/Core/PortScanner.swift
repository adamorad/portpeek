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
            let queue = DispatchQueue(label: "portpeek.probe.\(port)")
            // OSAllocatedUnfairLock provides thread-safe one-shot resume without
            // relying on the serial queue guarantee that the compiler cannot verify.
            let didResume = OSAllocatedUnfairLock(initialState: false)

            // tryConsume returns true the first time it is called, false on all
            // subsequent calls — ensures the continuation is resumed exactly once.
            let tryConsume = {
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

            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + self.timeout) {
                guard tryConsume() else { return }
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }
}
