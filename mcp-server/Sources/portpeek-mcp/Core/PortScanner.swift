import Foundation
import Darwin

final class PortScanner {
    private let timeoutMicroseconds: Int32
    private let queue = DispatchQueue(label: "com.portpeek.scanner", attributes: .concurrent)

    init(timeout: TimeInterval = 0.2) {
        self.timeoutMicroseconds = Int32(timeout * 1_000_000)
    }

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
        guard port >= 1, port <= 65535 else { return false }
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.tcpProbe(port: UInt16(port))) }
        }
    }

    private func tcpProbe(port: UInt16) -> Bool {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }

        let flags = fcntl(sock, F_GETFL, 0)
        guard flags >= 0, fcntl(sock, F_SETFL, flags | O_NONBLOCK) == 0 else { return false }

        var addr = sockaddr_in()
        addr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = port.bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let rc = withUnsafePointer(to: addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if rc == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var writefds = fd_set()
        fdZero(&writefds)
        fdSet(sock, &writefds)
        var tv = timeval(tv_sec: 0, tv_usec: timeoutMicroseconds)
        guard Darwin.select(sock + 1, nil, &writefds, nil, &tv) > 0 else { return false }

        var soError: Int32 = 0
        var soErrorLen = socklen_t(MemoryLayout<Int32>.size)
        Darwin.getsockopt(sock, SOL_SOCKET, SO_ERROR, &soError, &soErrorLen)
        return soError == 0
    }

    private func fdZero(_ set: inout fd_set) {
        withUnsafeMutableBytes(of: &set) { $0.initializeMemory(as: UInt8.self, repeating: 0) }
    }

    private func fdSet(_ fd: Int32, _ set: inout fd_set) {
        withUnsafeMutablePointer(to: &set) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: MemoryLayout<fd_set>.size / MemoryLayout<Int32>.size) { bits in
                bits[Int(fd) / 32] |= Int32(bitPattern: 1 << (UInt32(fd) % 32))
            }
        }
    }
}
