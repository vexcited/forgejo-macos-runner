import Foundation

extension AppPreferences {
  enum Key {
    static let migratedLegacyDefaults = "migratedLegacyDefaults"
    static let selectedImage = "selectedImage"
    static let provisionedImages = "provisionedImages"
    static let provisionedImageRevisions = "provisionedImageRevisions"
    static let imageOrigins = "imageOrigins"
    static let tartExecutablePath = "tartExecutablePath"
    static let runnerVersion = "runnerVersion"
    static let xcodeApplicationPath = "xcodeApplicationPath"
    static let vmPrefix = "vmPrefix"
    static let sandboxDNSServers = "sandboxDNSServers"
    static let showMenuBarItem = "showMenuBarItem"
    static let keepRunningInBackground = "keepRunningInBackground"
    static let launchControllerAutomatically = "launchControllerAutomatically"
    static let preventSleep = "preventSleep"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    static let all = [
      selectedImage, provisionedImages, tartExecutablePath, runnerVersion, xcodeApplicationPath,
      vmPrefix, showMenuBarItem, keepRunningInBackground, launchControllerAutomatically,
      preventSleep,
    ]

    // timeouts that used to be settings, removed from the defaults on launch.
    static let retiredTimeouts = [
      "bootTimeoutSeconds", "provisioningSSHTimeoutSeconds", "sshTimeoutSeconds",
      "runnerSessionTimeoutSeconds", "retryDelaySeconds",
    ]
  }
}
