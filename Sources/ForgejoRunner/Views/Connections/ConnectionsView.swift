import SwiftUI

struct ConnectionsView: View {
  @Environment(AppModel.self) private var model
  @State private var selection: String?
  @State private var editor: ConnectionPresentation?
  @State private var errorMessage: String?

  var body: some View {
    ConnectionsContent(
      selection: $selection,
      onAdd: { editor = ConnectionPresentation(originalName: nil, connection: nil) },
      onEdit: edit
    )
    .navigationTitle("Server Connections")
    .navigationSubtitle(subtitle)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("Reload", systemImage: "arrow.clockwise") {
          Task { await model.connections.load() }
        }
        .disabled(model.coordinator.isRunning || model.connections.isLoading)
        Button("Add", systemImage: "plus") {
          editor = ConnectionPresentation(originalName: nil, connection: nil)
        }
        .disabled(model.coordinator.isRunning || model.connections.errorMessage != nil)
        Button("Edit", systemImage: "pencil") {
          if let selectedConnection { edit(selectedConnection) }
        }
        .disabled(selectedConnection == nil || model.coordinator.isRunning)
      }
    }
    .safeAreaInset(edge: .bottom) {
      Banner(
        message: model.coordinator.isRunning
          ? "Stop the controller before changing runner identities."
          : "All connections share one capacity-one VM. Add only mutually trusted scopes.",
        style: model.coordinator.isRunning ? .warning : .info
      )
      .padding(12)
      .background(.bar)
    }
    .sheet(item: $editor) { presentation in
      ConnectionEditorView(presentation: presentation)
        .environment(model)
    }
    .alert("Connection error", isPresented: errorBinding) {
      Button("OK") { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "Unknown error")
    }
  }

  private var subtitle: String {
    let count = model.connections.connections.count
    return "\(count) registration\(count == 1 ? "" : "s")"
  }

  private var selectedConnection: RunnerConnection? {
    model.connections.connections.first { $0.id == selection }
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }

  private func edit(_ connection: RunnerConnection) {
    guard !model.coordinator.isRunning else { return }
    editor = ConnectionPresentation(originalName: connection.name, connection: connection)
  }
}
