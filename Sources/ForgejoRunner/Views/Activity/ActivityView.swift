import SwiftUI

struct ActivityView: View {
  @Environment(AppModel.self) private var model
  @State private var query = ""

  var body: some View {
    VStack(spacing: 0) {
      if model.activity.entries.isEmpty {
        ContentUnavailableView(
          "No activity yet",
          systemImage: "waveform.path.ecg",
          description: Text(
            "Controller and image lifecycle events appear here. Runner tokens are never logged.")
        )
        .frame(maxHeight: .infinity)
      } else if filteredEntries.isEmpty {
        ContentUnavailableView.search(text: query)
          .frame(maxHeight: .infinity)
      } else {
        List(filteredEntries) { entry in
          ActivityRow(entry: entry)
            .padding(.vertical, 3)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
      }

      if !model.operationOutput.isEmpty {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          CardHeader(title: "Operation output", symbol: "terminal") {
            Text("Every command is also written to the Logs folder")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          ConsoleView(output: model.operationOutput)
        }
        .padding(14)
        .background(.bar)
      }
    }
    .navigationTitle("Activity")
    .navigationSubtitle("\(model.activity.entries.count) events")
    .searchable(text: $query, placement: .toolbar, prompt: "Filter events")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("Open Logs", systemImage: "folder") {
          model.revealLogs()
        }
        .help("Reveal the command logs in Finder.")
        Button("Clear", systemImage: "trash") {
          model.activity.clear()
        }
        .disabled(model.activity.entries.isEmpty)
        .help("Clear the events shown here.")
      }
    }
  }

  private var filteredEntries: [ActivityEntry] {
    let entries = model.activity.entries.reversed()
    guard !query.isEmpty else { return Array(entries) }
    return entries.filter { $0.message.localizedCaseInsensitiveContains(query) }
  }
}
