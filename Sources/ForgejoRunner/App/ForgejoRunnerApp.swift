import AppKit
import SwiftUI

@main
struct ForgejoRunnerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  private var model: AppModel {
    appDelegate.model
  }

  var body: some Scene {
    @Bindable var model = model

    Window("Forgejo Runner", id: "main") {
      MainWindowView()
        .environment(model)
        .containerBackground(.regularMaterial, for: .window)
    }
    .windowResizability(.contentSize)
    .windowBackgroundDragBehavior(.enabled)
    .defaultLaunchBehavior(model.preferences.hasCompletedOnboarding ? .presented : .suppressed)
    .restorationBehavior(.disabled)
    .commands { AppCommands(model: model) }

    panelWindow(.connections)
    panelWindow(.images)
    panelWindow(.activity)

    Window("Set Up Forgejo Runner", id: "onboarding") {
      OnboardingView()
        .environment(model)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .windowBackgroundDragBehavior(.enabled)
    .defaultPosition(.center)
    .defaultLaunchBehavior(model.preferences.hasCompletedOnboarding ? .suppressed : .presented)
    .restorationBehavior(.disabled)
    // setup only ever opens on its own, so it stays out of the window menu.
    .commandsRemoved()

    Settings {
      SettingsView()
        .environment(model)
    }

    MenuBarExtra(isInserted: $model.isMenuBarItemInserted) {
      RunnerMenuView()
        .environment(model)
    } label: {
      Image(nsImage: MenuBarIcon.image(for: model.controllerStatus))
        .accessibilityLabel("Forgejo Runner, \(model.controllerStatus.title)")
    }
    .menuBarExtraStyle(.window)
  }

  private func panelWindow(_ panel: AppPanel) -> some Scene {
    Window(panel.title, id: panel.rawValue) {
      PanelWindow(panel: panel)
        .environment(model)
    }
    .defaultSize(width: 680, height: 520)
    .restorationBehavior(.disabled)
  }
}
