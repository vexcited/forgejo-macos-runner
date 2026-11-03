import Foundation

extension AppModel {
  var images: [TartImage] { imageLibrary.images }
  var writtenBytes: [String: Int64] { imageLibrary.writtenBytes }
  var isRefreshingImages: Bool { imageLibrary.isRefreshingImages }
  var isCloningImage: Bool { imageLibrary.isCloningImage }
  var isProvisioningImage: Bool { imageLibrary.isProvisioningImage }
  var isDeletingImage: Bool { imageLibrary.isDeletingImage }
  var isImageOperationRunning: Bool { imageLibrary.isImageOperationRunning }
  var activeClone: TartCloneRequest? { imageClones.activeClone }
  var cloneProgress: TartCloneProgress? { imageClones.cloneProgress }
  var isInterruptingClone: Bool { imageClones.isInterruptingClone }
  var pausedClone: PausedClone? { pausedClones.pausedClone }

  var imageErrorMessage: String? {
    get { imageLibrary.errorMessage }
    set { imageLibrary.errorMessage = newValue }
  }

  // raw stdout and stderr of the current or last image operation.
  var operationOutput: String { imageLibrary.operationOutput }

  // set after a clone to ask whether the new image should become the golden image.
  var pendingGoldenPrompt: GoldenImagePrompt? {
    get { imageClones.pendingGoldenPrompt }
    set { imageClones.pendingGoldenPrompt = newValue }
  }

  func refreshImages() async {
    await imageLibrary.refresh()
  }

  func cloneImage(source: String, name: String) async {
    await imageClones.cloneImage(source: source, name: name)
  }

  func measureWrittenBytes() {
    imageLibrary.measureWrittenBytes()
  }

  func resumePausedClone() async {
    await imageClones.resumePausedClone()
  }

  func pauseClone() async {
    await imageClones.pauseClone()
  }

  func cancelClone() async {
    await imageClones.cancelClone()
  }

  // stops the download or the setup that follows it and removes what was downloaded.
  func cancelImageSetup() async {
    if activeClone != nil {
      await cancelClone()
    } else if isProvisioningImage {
      await goldenImages.cancelProvisioning()
    } else if let prompt = pendingGoldenPrompt {
      pendingGoldenPrompt = nil
      await imageLibrary.delete(named: prompt.imageName)
    }
  }

  func discardPausedClone() {
    pausedClones.discard()
  }

  func deleteImage(_ image: TartImage) async {
    await imageLibrary.delete(image)
  }

  func useAsGoldenImage(_ name: String) async {
    await goldenImages.useAsGoldenImage(name)
  }

  func provisionGoldenImage() async {
    await goldenImages.provisionGoldenImage()
  }

  func resolveGoldenPrompt(use: Bool) async {
    guard let prompt = pendingGoldenPrompt else { return }
    pendingGoldenPrompt = nil
    guard use else { return }
    await useAsGoldenImage(prompt.imageName)
  }
}
