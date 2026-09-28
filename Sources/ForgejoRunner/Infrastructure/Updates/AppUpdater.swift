import Foundation
import Observation
import Sparkle

// finds a newer signed release in the update feed and installs it, through sparkle.
@MainActor
@Observable
final class AppUpdater {
  private let controller: SPUStandardUpdaterController?

  init(bundle: Bundle = .main) {
    controller =
      Self.isRelease(bundle)
      ? SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
      : nil
  }

  // a development build would offer to replace itself with the latest release.
  private static func isRelease(_ bundle: Bundle) -> Bool {
    #if DEBUG
      false
    #else
      bundle.bundleURL.pathExtension == "app"
        && bundle.object(forInfoDictionaryKey: "SUFeedURL") != nil
    #endif
  }

  var isAvailable: Bool {
    controller != nil
  }

  var automaticallyChecksForUpdates: Bool {
    get {
      access(keyPath: \.automaticallyChecksForUpdates)
      return controller?.updater.automaticallyChecksForUpdates ?? false
    }
    set {
      withMutation(keyPath: \.automaticallyChecksForUpdates) {
        controller?.updater.automaticallyChecksForUpdates = newValue
      }
    }
  }

  // a downloaded update is installed the next time the app quits.
  var automaticallyDownloadsUpdates: Bool {
    get {
      access(keyPath: \.automaticallyDownloadsUpdates)
      return controller?.updater.automaticallyDownloadsUpdates ?? false
    }
    set {
      withMutation(keyPath: \.automaticallyDownloadsUpdates) {
        controller?.updater.automaticallyDownloadsUpdates = newValue
      }
    }
  }

  var lastCheckDate: Date? {
    controller?.updater.lastUpdateCheckDate
  }

  func checkForUpdates() {
    controller?.checkForUpdates(nil)
  }
}
