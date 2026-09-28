import SwiftUI

// a connection with its server and labels, and optional actions on the trailing edge.
struct ConnectionRow<Actions: View>: View {
  let connection: RunnerConnection
  @ViewBuilder var actions: Actions

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "server.rack")
        .font(.title3)
        .foregroundStyle(.secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(connection.name)
            .font(.headline)
          Text(connection.url.host() ?? connection.url.absoluteString)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .help("\(connection.url.absoluteString), runner \(connection.uuid.uuidString.lowercased())")
        FlowLayout(spacing: 5) {
          ForEach(connection.labelNames, id: \.self) { label in
            Chip(text: label)
          }
        }
      }
      Spacer(minLength: 8)
      actions
    }
    .padding(.vertical, 4)
  }
}

extension ConnectionRow where Actions == EmptyView {
  init(connection: RunnerConnection) {
    self.init(connection: connection) { EmptyView() }
  }
}
