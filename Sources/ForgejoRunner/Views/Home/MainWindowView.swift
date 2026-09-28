import SwiftUI

struct MainWindowView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  var body: some View {
    HomeView()
      .onAppear {
        model.mainWindowDidOpen()
        // the app stays behind the setup window until setup has been finished once.
        if !model.preferences.hasCompletedOnboarding {
          openWindow(id: "onboarding")
          dismissWindow(id: "main")
        }
      }
      .onDisappear { model.mainWindowDidClose() }
  }
}
