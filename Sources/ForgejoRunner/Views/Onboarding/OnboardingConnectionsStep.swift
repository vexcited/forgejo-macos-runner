import SwiftUI

struct OnboardingConnectionsStep: View {
  @Environment(AppModel.self) private var model
  @State private var presentation: ConnectionPresentation?

  var body: some View {
    VStack(spacing: 0) {
      OnboardingStepHeader(step: .connections)
      Form {
        Section {
          Text(
            "In Forgejo, open the settings of a repository, organization or user, go to Actions > Runners and create a runner. Do not make it ephemeral. Copy its UUID and token here."
          )
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(.secondary)
        }
        Section {
          if model.connections.connections.isEmpty {
            Text("No connections yet.")
              .foregroundStyle(.secondary)
              .transition(.blurFade)
          }
          ForEach(model.connections.connections, id: \.name) { connection in
            ConnectionRow(connection: connection) {
              Button("Edit", systemImage: "pencil") {
                presentation = ConnectionPresentation(
                  originalName: connection.name, connection: connection)
              }
              .help("Edit \(connection.name)")
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
              .imageScale(.large)
            }
            .transition(.blurFade)
          }
          if let error = model.connections.errorMessage {
            Banner(message: error, style: .error)
          }
        } header: {
          HStack {
            Text("Connections")
            Spacer()
            Button("Add Connection", systemImage: "plus") {
              presentation = ConnectionPresentation(originalName: nil, connection: nil)
            }
          }
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .animation(.smooth(duration: 0.4), value: model.connections.connections.map(\.name))
    }
    .sheet(item: $presentation) { presentation in
      ConnectionEditorView(presentation: presentation)
    }
  }
}
