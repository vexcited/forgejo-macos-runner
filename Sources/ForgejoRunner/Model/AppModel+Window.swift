import AppKit
import SwiftUI

extension AppModel {
  var isMenuBarItemInserted: Bool {
    get { preferences.showMenuBarItem || preferences.keepRunningInBackground }
    set { preferences.showMenuBarItem = newValue }
  }

  func showMainWindow(using openWindow: OpenWindowAction) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    openWindow(id: preferences.hasCompletedOnboarding ? "main" : "onboarding")
  }

  // in background mode the app leaves the dock while its main window is closed.
  func updateDockPresence() {
    let policy: NSApplication.ActivationPolicy =
      preferences.keepRunningInBackground && !isMainWindowOpen ? .accessory : .regular
    guard NSApp.activationPolicy() != policy else { return }
    NSApp.setActivationPolicy(policy)
    if policy == .accessory {
      // keeps an open settings window in front after leaving the dock.
      NSApp.activate()
    }
  }

  func revealTartHome() {
    NSWorkspace.shared.activateFileViewerSelecting([paths.tartHome])
  }

  func revealConnectionsFile() {
    NSWorkspace.shared.activateFileViewerSelecting([paths.connectionsFile])
  }

  func revealLogs() {
    NSWorkspace.shared.activateFileViewerSelecting([paths.logsDirectory])
  }
}
