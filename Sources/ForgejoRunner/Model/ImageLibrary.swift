import Foundation
import Observation

// the local tart images and the busy, error and output state every image operation shares.
@MainActor
@Observable
final class ImageLibrary {
  private let tart: TartClient
  private let tartConfigurator: TartConfigurator
  private let preferences: AppPreferences
  private let activity: ActivityLog
  private let coordinator: RunnerCoordinator

  private(set) var images: [TartImage] = []
  // what each session vm wrote on top of the golden image it was cloned from.
  private(set) var writtenBytes: [String: Int64] = [:]
  private(set) var isRefreshingImages = false
  var isCloningImage = false
  var isProvisioningImage = false
  private(set) var isDeletingImage = false
  var errorMessage: String?
  // raw stdout and stderr of the current or last image operation.
  private(set) var operationOutput = ""

  init(
    tart: TartClient,
    tartConfigurator: TartConfigurator,
    preferences: AppPreferences,
    activity: ActivityLog,
    coordinator: RunnerCoordinator
  ) {
    self.tart = tart
    self.tartConfigurator = tartConfigurator
    self.preferences = preferences
    self.activity = activity
    self.coordinator = coordinator
  }

  var isImageOperationRunning: Bool {
    isRefreshingImages || isCloningImage || isProvisioningImage || isDeletingImage
  }

  func refresh() async {
    tartConfigurator.configure()
    isRefreshingImages = true
    defer { isRefreshingImages = false }
    do {
      images = try await tart.images()
      measureWrittenBytes()
      errorMessage = nil
    } catch {
      images = []
      errorMessage = error.localizedDescription
    }
  }

  // cheap enough to repeat while a job runs, it only reads the disk files' metadata.
  func measureWrittenBytes() {
    writtenBytes = Dictionary(
      uniqueKeysWithValues: images.filter { $0.name.hasPrefix(VMName.controllerPrefix) }
        .compactMap { image in
          let disk = tart.factory.vmDirectory(for: image.name).appending(path: "disk.img")
          return ClonedFileSize.privateBytes(of: disk).map { (image.name, $0) }
        })
  }

  func delete(named name: String) async {
    await refresh()
    guard let image = images.first(where: { $0.name == name }) else { return }
    await delete(image)
  }

  func delete(_ image: TartImage) async {
    guard !coordinator.isRunning else {
      errorMessage = AppModelError.stopControllerFirst.localizedDescription
      return
    }
    guard !isImageOperationRunning else {
      errorMessage = AppModelError.imageOperationRunning.localizedDescription
      return
    }
    tartConfigurator.configure()
    isDeletingImage = true
    defer { isDeletingImage = false }
    do {
      if image.isRunning {
        try await tart.stop(name: image.name, timeoutSeconds: 30)
      }
      try await tart.delete(name: image.name)
      preferences.clearProvisioned(image.name)
      preferences.setOrigin(nil, of: image.name)
      if preferences.selectedImage == image.name {
        preferences.selectedImage = ""
      }
      activity.append("Deleted Tart image \(image.name).")
      await refresh()
    } catch {
      errorMessage = error.localizedDescription
      activity.append("Image deletion failed: \(error.localizedDescription)")
    }
  }

  func clearOperationOutput() {
    operationOutput = ""
  }

  func appendOperationOutput(_ output: String) {
    operationOutput = String((operationOutput + output).suffix(100_000))
  }
}
