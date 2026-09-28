import Foundation
import GuestKit
import Observation

@MainActor
@Observable
final class AppPreferences {
  private let defaults: UserDefaults

  var selectedImage: String {
    didSet { defaults.set(selectedImage, forKey: Key.selectedImage) }
  }

  // the guest helper revision a golden image must carry. revision 2 moved runner
  // tokens out of the vm and revision 3 added the per-session sandbox preparation,
  // so older images need provisioning again.
  static let guestHelperRevision = RunnerSessionProtocol.version

  // Images this app has provisioned as golden runner images, with the guest helper
  // revision each one carries. Used to decide whether designating an image as golden
  // should provision it automatically. A fresh clone is unprovisioned; a name is
  // cleared when its image is deleted or re-cloned.
  private(set) var provisionedImages: [String: Int] {
    didSet { defaults.set(provisionedImages, forKey: Key.provisionedImageRevisions) }
  }

  var tartExecutablePath: String {
    didSet { defaults.set(tartExecutablePath, forKey: Key.tartExecutablePath) }
  }

  var runnerVersion: String {
    didSet { defaults.set(runnerVersion, forKey: Key.runnerVersion) }
  }

  var xcodeApplicationPath: String {
    didSet { defaults.set(xcodeApplicationPath, forKey: Key.xcodeApplicationPath) }
  }

  var vmPrefix: String {
    didSet { defaults.set(vmPrefix, forKey: Key.vmPrefix) }
  }

  // resolvers the sandboxed vms use, since the sandbox blocks the vmnet gateway that
  // would otherwise answer dns. they must be public ipv4 addresses.
  var sandboxDNSServers: [String] {
    didSet { defaults.set(sandboxDNSServers, forKey: Key.sandboxDNSServers) }
  }

  var showMenuBarItem: Bool {
    didSet { defaults.set(showMenuBarItem, forKey: Key.showMenuBarItem) }
  }

  var keepRunningInBackground: Bool {
    didSet { defaults.set(keepRunningInBackground, forKey: Key.keepRunningInBackground) }
  }

  var launchControllerAutomatically: Bool {
    didSet {
      defaults.set(launchControllerAutomatically, forKey: Key.launchControllerAutomatically)
    }
  }

  var preventSleep: Bool {
    didSet { defaults.set(preventSleep, forKey: Key.preventSleep) }
  }

  // the main window shows the setup flow until it has been finished once.
  var hasCompletedOnboarding: Bool {
    didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    Self.migrateLegacyDefaults(into: defaults)
    selectedImage = defaults.string(forKey: Key.selectedImage) ?? ""
    let legacyProvisionedImages = defaults.stringArray(forKey: Key.provisionedImages)
    let hadProvisionedRecord =
      legacyProvisionedImages != nil
      || defaults.object(forKey: Key.provisionedImageRevisions) != nil
    // migration: names recorded before revisions existed carry the first helper.
    provisionedImages =
      defaults.dictionary(forKey: Key.provisionedImageRevisions) as? [String: Int]
      ?? Dictionary(uniqueKeysWithValues: (legacyProvisionedImages ?? []).map { ($0, 1) })
    tartExecutablePath = defaults.string(forKey: Key.tartExecutablePath) ?? "/opt/homebrew/bin/tart"
    runnerVersion = defaults.string(forKey: Key.runnerVersion) ?? "13.2.0"
    xcodeApplicationPath = defaults.string(forKey: Key.xcodeApplicationPath) ?? ""
    vmPrefix = defaults.string(forKey: Key.vmPrefix) ?? "forgejo"
    sandboxDNSServers =
      defaults.stringArray(forKey: Key.sandboxDNSServers) ?? ["9.9.9.9"]
    for key in Key.retiredTimeouts {
      defaults.removeObject(forKey: key)
    }
    showMenuBarItem = defaults.object(forKey: Key.showMenuBarItem) as? Bool ?? true
    keepRunningInBackground =
      defaults.object(forKey: Key.keepRunningInBackground) as? Bool ?? true
    launchControllerAutomatically =
      defaults.object(forKey: Key.launchControllerAutomatically) as? Bool ?? false
    preventSleep = defaults.object(forKey: Key.preventSleep) as? Bool ?? false
    hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)

    // migration: a golden image chosen before this app tracked provisioning is
    // assumed already provisioned, so it does not read as "needs provisioning".
    if !hadProvisionedRecord, !selectedImage.isEmpty {
      provisionedImages[selectedImage] = 1
    }
  }

  func isProvisioned(_ image: String) -> Bool {
    provisionedImages[image, default: 0] >= Self.guestHelperRevision
  }

  func markProvisioned(_ image: String) {
    provisionedImages[image] = Self.guestHelperRevision
  }

  func clearProvisioned(_ image: String) {
    provisionedImages[image] = nil
  }

  // copies preferences saved under the bundle identifier used before the app was renamed.
  private static func migrateLegacyDefaults(into defaults: UserDefaults) {
    guard !defaults.bool(forKey: Key.migratedLegacyDefaults),
      let legacy = UserDefaults(suiteName: "com.vexcited.ForgejoMacOSRunner")
    else { return }
    for key in Key.all where defaults.object(forKey: key) == nil {
      if let value = legacy.object(forKey: key) {
        defaults.set(value, forKey: key)
      }
    }
    defaults.set(true, forKey: Key.migratedLegacyDefaults)
  }
}
