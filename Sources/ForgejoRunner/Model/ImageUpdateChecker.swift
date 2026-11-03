import Foundation
import Observation

// compares the local images with what their registry publishes as latest.
@MainActor
@Observable
final class ImageUpdateChecker {
  private let preferences: AppPreferences
  private let tartHome: URL

  private(set) var statuses: [String: ImageUpdateStatus] = [:]
  // the registry repository of each image that can be updated.
  private(set) var repositories: [String: String] = [:]

  init(preferences: AppPreferences, tartHome: URL) {
    self.preferences = preferences
    self.tartHome = tartHome
  }

  func check(_ images: [TartImage]) async {
    var statuses: [String: ImageUpdateStatus] = [:]
    var repositories: [String: String] = [:]
    for image in images where !image.name.hasPrefix(VMName.controllerPrefix) {
      let origin = preferences.origin(of: image.name)
      // images cloned before origins were recorded are matched to cirrus labs by name.
      let repository = origin?.repository ?? "cirruslabs/macos-\(image.name)"
      guard let tags = try? await RegistryClient.tags(of: repository), !tags.isEmpty,
        let latest = try? await RegistryClient.latestVersion(of: repository, tags: tags)
      else { continue }
      repositories[image.name] = repository
      statuses[image.name] = status(of: image.name, origin: origin, latest: latest)
    }
    self.statuses = statuses
    self.repositories = repositories
  }

  private func status(
    of name: String,
    origin: ImageOrigin?,
    latest: (manifest: RegistryManifest, version: String?)
  ) -> ImageUpdateStatus {
    let available = ImageUpdateStatus.available(
      version: latest.version, uploadedAt: latest.manifest.uploadedAt)
    if let origin {
      return origin.digest == latest.manifest.digest ? .upToDate : available
    }
    // without a recorded digest, an image cloned before latest was published is older.
    let folder = tartHome.appending(path: "vms", directoryHint: .isDirectory)
      .appending(path: name, directoryHint: .isDirectory)
    guard let uploadedAt = latest.manifest.uploadedAt,
      let createdAt = try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate
    else { return available }
    return createdAt < uploadedAt ? available : .upToDate
  }
}
