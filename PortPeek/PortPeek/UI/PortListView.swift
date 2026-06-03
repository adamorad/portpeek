import SwiftUI

struct PortListView: View {
    @EnvironmentObject var registry: PortRegistry

    private var listening: [PortEntry] {
        registry.entries.filter { $0.status == .listening }
    }

    private var reserved: [PortEntry] {
        registry.entries.filter {
            if case .reserved = $0.status { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !listening.isEmpty {
                    SectionHeader(title: "Listening")
                    ForEach(listening) { entry in
                        PortRowView(entry: entry)
                        if entry.port != listening.last?.port {
                            Divider().opacity(0.15).padding(.leading, 34)
                        }
                    }
                }
                if !reserved.isEmpty {
                    if !listening.isEmpty { Divider().opacity(0.25).padding(.vertical, 4) }
                    SectionHeader(title: "Reserved by Agent")
                    ForEach(reserved) { entry in
                        PortRowView(entry: entry)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
