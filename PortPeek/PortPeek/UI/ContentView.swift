import SwiftUI

struct ContentView: View {
    @EnvironmentObject var registry: PortRegistry

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PortPeek")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                MCPStatusPill(isRunning: registry.isMCPServerRunning)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider().opacity(0.4)

            if registry.entries.isEmpty {
                EmptyStateView()
            } else {
                PortListView()
            }

            Divider().opacity(0.4)

            HStack {
                Spacer()
                if let last = registry.lastScanned {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("scanned \(max(0, Int(-last.timeIntervalSinceNow)))s ago")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .frame(width: 316)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

struct MCPStatusPill: View {
    let isRunning: Bool
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
                .shadow(color: isRunning ? .green.opacity(0.7) : .clear, radius: 3)
            Text("MCP \(isRunning ? "on" : "off")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isRunning ? Color.green.opacity(0.9) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(isRunning ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1)))
        .overlay(Capsule().strokeBorder(isRunning ? Color.green.opacity(0.25) : .clear, lineWidth: 0.5))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🔌").font(.system(size: 28)).opacity(0.4)
            Text("No active ports")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Scanning all ports…")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
