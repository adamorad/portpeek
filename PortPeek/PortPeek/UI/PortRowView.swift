import SwiftUI

struct PortRowView: View {
    let entry: PortEntry
    @EnvironmentObject var registry: PortRegistry
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var labelDraft = ""

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(status: entry.status)

            VStack(alignment: .leading, spacing: 1) {
                if isEditing {
                    TextField("Label…", text: $labelDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .onSubmit { commitLabel() }
                        .onAppear { labelDraft = entry.userLabel ?? "" }
                } else {
                    Text(entry.displayName)
                        .font(.system(size: 13, weight: entry.userLabel != nil ? .medium : .regular))
                        .foregroundStyle(entry.userLabel != nil ? Color.primary : Color.secondary.opacity(0.5))
                        .italic(entry.userLabel == nil)
                        .onTapGesture(count: 2) { startEditing() }
                }
                subtitleText
            }

            Spacer()

            Text(entry.port, format: .number.grouping(.never))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            if isHovered {
                HStack(spacing: 2) {
                    if entry.status == .listening {
                        Button { openInBrowser() } label: {
                            Image(systemName: "arrow.up.right").font(.system(size: 11))
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    if case .reserved = entry.status {
                        Button { registry.release(port: entry.port) } label: {
                            Image(systemName: "xmark").font(.system(size: 11))
                        }
                        .buttonStyle(GlassButtonStyle(isDestructive: true))
                    }
                    Menu {
                        Button("Rename…") { startEditing() }
                        Button("Copy URL") { copyURL() }
                        if case .reserved = entry.status {
                            Button("Release Reservation", role: .destructive) {
                                registry.release(port: entry.port)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 11))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    @ViewBuilder private var subtitleText: some View {
        switch entry.status {
        case .listening:
            Text("listening").font(.system(size: 11)).foregroundStyle(.tertiary)
        case .reserved(_, let expires):
            Text("agent reserved · \(max(0, Int(expires.timeIntervalSinceNow / 60)))m left")
                .font(.system(size: 11)).foregroundStyle(.blue.opacity(0.8))
        }
    }

    private func startEditing() {
        labelDraft = entry.userLabel ?? ""
        isEditing = true
    }

    private func commitLabel() {
        isEditing = false
        let trimmed = labelDraft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            registry.labelStore.removeLabel(for: entry.port)
        } else {
            registry.setLabel(trimmed, for: entry.port)
        }
    }

    private func openInBrowser() {
        if let url = URL(string: "http://localhost:\(entry.port)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://localhost:\(entry.port)", forType: .string)
    }
}

struct StatusDot: View {
    let status: PortStatus
    @State private var glowing = false

    var color: Color {
        switch status {
        case .listening: return .green
        case .reserved:  return .blue
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(glowing ? 0.8 : 0.4), radius: glowing ? 4 : 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
    }
}

struct GlassButtonStyle: ButtonStyle {
    var isDestructive = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(
                configuration.isPressed
                    ? (isDestructive ? Color.red.opacity(0.15) : Color.primary.opacity(0.12))
                    : Color.primary.opacity(0.07)
            ))
            .foregroundStyle(isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
    }
}
