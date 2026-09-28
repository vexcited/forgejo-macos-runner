import SwiftUI

// the app's own menus, in place of the ones macOS adds that do nothing here.
struct AppCommands: Commands {
  let model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandMenu("Runner") {
      Button("Start Runner") {
        Task { await model.startController() }
      }
      .keyboardShortcut("r")
      .disabled(!isSetUp || model.coordinator.isRunning || !model.canStartController)
      Button("Stop Runner") {
        Task { await model.stopController() }
      }
      .keyboardShortcut(".")
      .disabled(!model.coordinator.isRunning)
      Divider()
      Button("Show Logs in Finder") { model.revealLogs() }
    }

    CommandGroup(before: .toolbar) {
      ForEach(Array(AppPanel.allCases.enumerated()), id: \.element) { index, panel in
        Button(panel.title) {
          NSApp.activate()
          openWindow(id: panel.rawValue)
        }
        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
        .disabled(!isSetUp)
      }
      Divider()
    }

    CommandGroup(replacing: .help) {
      Link("Report an Issue", destination: Self.repository.appending(path: "issues"))
      Link("View Releases", destination: Self.repository.appending(path: "releases"))
    }
  }

  private var isSetUp: Bool {
    model.preferences.hasCompletedOnboarding
  }

  private static let repository = URL(string: "https://code.vexcited.com/forgejo/macos-runner")!
}
