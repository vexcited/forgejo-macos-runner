import SwiftUI

struct ConnectionsContent: View {
  @Environment(AppModel.self) private var model
  @Binding var selection: String?
  let onAdd: () -> Void
  let onEdit: (RunnerConnection) -> Void

  var body: some View {
    Group {
      if let manifestError = model.connections.errorMessage {
        ContentUnavailableView {
          Label("Connections could not be loaded", systemImage: "doc.badge.ellipsis")
        } description: {
          Text(manifestError)
        } actions: {
          Button("Retry") {
            Task { await model.connections.load() }
          }
          if FileManager.default.fileExists(atPath: model.paths.connectionsFile.path) {
            Button("Reveal Manifest") { model.revealConnectionsFile() }
          }
        }
      } else if model.connections.connections.isEmpty {
        ContentUnavailableView {
          Label("No server connections", systemImage: "point.3.connected.trianglepath.dotted")
        } description: {
          Text(
            "Add each repository, organization, user, or global runner registration managed by this Mac."
          )
        } actions: {
          Button("Add Connection", action: onAdd)
            .disabled(model.coordinator.isRunning || model.connections.errorMessage != nil)
        }
      } else {
        List(selection: $selection) {
          ForEach(model.connections.connections) { connection in
            ConnectionRow(connection: connection)
              .tag(connection.id)
              .contextMenu {
                Button("Edit") { onEdit(connection) }
                  .disabled(model.coordinator.isRunning)
              }
          }
        }
        .listStyle(.inset)
      }
    }
  }
}
