import Foundation

enum LaunchAgent {
    static let label = "io.portpeek.mcp"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func install() {
        let binary = CommandLine.arguments[0]
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array><string>\(binary)</string></array>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><true/>
            <key>StandardOutPath</key><string>/tmp/portpeek-mcp.log</string>
            <key>StandardErrorPath</key><string>/tmp/portpeek-mcp.log</string>
        </dict>
        </plist>
        """
        do {
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            Process.run("/bin/launchctl", arguments: ["load", plistURL.path])
            print("[portpeek-mcp] launch agent installed — will start automatically at login")
            print("[portpeek-mcp] plist: \(plistURL.path)")
        } catch {
            fputs("[portpeek-mcp] failed to install launch agent: \(error)\n", stderr)
            exit(1)
        }
    }

    static func uninstall() {
        Process.run("/bin/launchctl", arguments: ["unload", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
        print("[portpeek-mcp] launch agent removed")
    }
}

// Helper
private extension Process {
    @discardableResult
    static func run(_ executablePath: String, arguments: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executablePath)
        p.arguments = arguments
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
}
