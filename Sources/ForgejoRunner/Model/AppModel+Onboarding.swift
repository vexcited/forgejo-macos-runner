import Foundation

extension AppModel {
  var isTartInstalled: Bool {
    FileManager.default.isExecutableFile(atPath: preferences.tartExecutablePath)
  }

  var isGoldenImageReady: Bool {
    !preferences.selectedImage.isEmpty && preferences.isProvisioned(preferences.selectedImage)
  }

  func finishOnboarding(startingController: Bool) async {
    preferences.hasCompletedOnboarding = true
    if startingController {
      await startController()
    }
  }
}
