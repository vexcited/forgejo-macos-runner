import Foundation
import Observation

// the image picked in setup, shared by the list and the footer button.
@MainActor
@Observable
final class OnboardingImageChoice {
  var source = "ghcr.io/cirruslabs/macos-golden-gate-xcode:latest"
  var name = "golden-gate-xcode"
  // the image this session downloaded or provisioned. only that one shows as ready,
  // a golden image from an earlier run is picked again from the list.
  private var setUpImage: String?

  func phase(in model: AppModel) -> OnboardingImagePhase {
    if model.activeClone != nil { return .downloading }
    if model.isProvisioningImage || model.pendingGoldenPrompt != nil { return .settingUp }
    if model.pausedClone != nil { return .paused }
    if model.isGoldenImageReady, setUpImage == model.preferences.selectedImage { return .ready }
    return .picking
  }

  // an image already on this mac is provisioned as is, without downloading it again.
  func isDownloaded(in model: AppModel) -> Bool {
    model.images.contains { $0.name == name }
  }

  func isReadyToUse(in model: AppModel) -> Bool {
    isDownloaded(in: model) && model.preferences.isProvisioned(name)
  }

  func actionTitle(in model: AppModel) -> String {
    guard isDownloaded(in: model) else { return "Download and Provision" }
    return model.preferences.isProvisioned(name) ? "Use" : "Provision"
  }

  // an image that is already set up is only selected, the caller moves on.
  func start(in model: AppModel) async {
    if isReadyToUse(in: model) {
      await model.useAsGoldenImage(name)
      return
    }
    setUpImage = name
    if isDownloaded(in: model) {
      await model.useAsGoldenImage(name)
    } else {
      await model.cloneImage(source: source, name: name)
    }
  }

  func chooseAnother() {
    setUpImage = nil
  }
}
