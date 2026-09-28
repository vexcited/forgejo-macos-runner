import SwiftUI

struct OperationLogsPanel: View {
  let title: String
  let output: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      CardHeader(title: title, symbol: "terminal") {
        Text("Raw stdout and stderr")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      ConsoleView(output: output, maxHeight: 190)
    }
    .padding(14)
    .background(.bar)
  }
}
