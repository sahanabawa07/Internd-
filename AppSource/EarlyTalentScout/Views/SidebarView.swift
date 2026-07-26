import SwiftUI

struct SidebarView: View {
    let store: AppStore

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selection) {
            Section {
                Button {
                    store.selection = nil
                } label: {
                    Label("Career garden", systemImage: "square.grid.2x2.fill")
                }
                .buttonStyle(.plain)
            }
            Section("Workspace") {
                ForEach(WorkspaceSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon).tag(Optional(section))
                }
            }
            Section("Agents") {
                ForEach(store.run?.agents ?? []) { agent in
                    HStack(spacing: 8) {
                        Image(systemName: symbol(for: agent.status)).foregroundStyle(color(for: agent.status))
                        Text(agent.name)
                    }
                    .help(agent.status.rawValue)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Internd")
    }

    private func symbol(for status: AgentProgress.Status) -> String {
        switch status { case .waiting: "circle"; case .working: "arrow.triangle.2.circlepath"; case .complete: "checkmark.circle.fill"; case .failed: "exclamationmark.triangle.fill" }
    }
    private func color(for status: AgentProgress.Status) -> Color {
        switch status { case .waiting: .secondary; case .working: .blue; case .complete: .green; case .failed: .orange }
    }
}
