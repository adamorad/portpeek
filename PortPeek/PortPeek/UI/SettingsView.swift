import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var registry: PortRegistry
    @Environment(\.dismiss) var dismiss
    @State private var newPortText = ""
    @State private var showAddPort = false
    @AppStorage("portpeek.scanInterval") private var scanInterval = 3.0
    @AppStorage("portpeek.reservationTTL") private var reservationTTL = 5
    @AppStorage("portpeek.showAvailable") private var showAvailable = false
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("‹ Back") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                Spacer()
                Text("Settings").font(.system(size: 13, weight: .bold))
                Spacer()
                Color.clear.frame(width: 50)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider().opacity(0.4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSection(title: "MCP Server") {
                        HStack {
                            Text("Port").font(.system(size: 13))
                            Spacer()
                            HStack(spacing: 5) {
                                Text("27182").foregroundStyle(.secondary).font(.system(size: 12))
                                Circle().fill(.green).frame(width: 6, height: 6)
                                    .shadow(color: .green.opacity(0.6), radius: 3)
                            }
                        }
                        Button { copyClaudeConfig() } label: {
                            Label("Copy Claude Code config", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(SnippetButtonStyle())
                        Button { copyClaudeMDSnippet() } label: {
                            Label("Copy CLAUDE.md snippet", systemImage: "doc.text")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(SnippetButtonStyle())
                    }

                    SettingsSection(title: "Monitored Ports") {
                        FlowLayout(spacing: 5) {
                            ForEach(registry.monitoredPorts, id: \.self) { port in
                                PortTag(port: port) { registry.removePort(port) }
                            }
                            Button("＋ Add") { showAddPort = true }
                                .buttonStyle(AddTagButtonStyle())
                        }
                        if showAddPort {
                            HStack {
                                TextField("Port number", text: $newPortText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .onSubmit { commitAddPort() }
                                Button("Add", action: commitAddPort)
                                Button("Cancel") { showAddPort = false; newPortText = "" }
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 12))
                        }
                    }

                    SettingsSection(title: "Preferences") {
                        HStack {
                            Text("Scan interval").font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $scanInterval) {
                                Text("2s").tag(2.0)
                                Text("3s").tag(3.0)
                                Text("5s").tag(5.0)
                                Text("10s").tag(10.0)
                            }
                            .labelsHidden()
                            .frame(width: 80)
                            .onChange(of: scanInterval) { _, newValue in
                                registry.startScanning(interval: newValue)
                            }
                        }
                        HStack {
                            Text("Reservation TTL").font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $reservationTTL) {
                                Text("2m").tag(2)
                                Text("5m").tag(5)
                                Text("10m").tag(10)
                            }
                            .labelsHidden()
                            .frame(width: 80)
                        }
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .font(.system(size: 13))
                            .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                        Toggle("Show available ports", isOn: $showAvailable)
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .frame(width: 316)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func commitAddPort() {
        if let port = Int(newPortText.trimmingCharacters(in: .whitespaces)), (1...65535).contains(port) {
            registry.addPort(port)
        }
        newPortText = ""
        showAddPort = false
    }

    private func copyClaudeConfig() {
        let json = #"{ "mcpServers": { "portpeek": { "url": "http://localhost:27182" } } }"#
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    private func copyClaudeMDSnippet() {
        let snippet = """
        ## Port management
        Before starting any dev server, call portpeek MCP `get_available_port` with your preferred port.
        Always `release_port` when the server stops.
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[PortPeek] Launch at login error: \(error)")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 9) { content() }
        }
        .padding(14)
        Divider().opacity(0.25)
    }
}

struct PortTag: View {
    let port: Int
    let onRemove: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 3) {
            Text("\(port)").font(.system(size: 11, weight: .medium))
            if hovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .onHover { hovered = $0 }
    }
}

struct SnippetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

struct AddTagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.blue.opacity(0.25), lineWidth: 0.5))
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 280
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
