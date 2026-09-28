import Foundation

// designates the golden runner image and provisions it.
@MainActor
final class GoldenImageController {
  private let imageLibrary: ImageLibrary
  private let tart: TartClient
  private let tartConfigurator: TartConfigurator
  private let paths: AppPaths
  private let preferences: AppPreferences
  private let activity: ActivityLog
  private let coordinator: RunnerCoordinator
  private let provisioner: GoldenImageProvisioner
  private var provisionTask: Task<Void, Never>?
  private var provisioningName: String?

  init(
    imageLibrary: ImageLibrary,
    tart: TartClient,
    tartConfigurator: TartConfigurator,
    paths: AppPaths,
    preferences: AppPreferences,
    activity: ActivityLog,
    coordinator: RunnerCoordinator,
    provisioner: GoldenImageProvisioner
  ) {
    self.imageLibrary = imageLibrary
    self.tart = tart
    self.tartConfigurator = tartConfigurator
    self.paths = paths
    self.preferences = preferences
    self.activity = activity
    self.coordinator = coordinator
    self.provisioner = provisioner
  }

  // Designates an image as the golden runner image and provisions it automatically
  // when it has not been provisioned yet. Called from the images list and the
  // post-clone prompt, so the manual Provision step is no longer required.
  func useAsGoldenImage(_ name: String) async {
    guard !name.hasPrefix(VMName.controllerPrefix) else {
      imageLibrary.errorMessage = AppConfigurationError.reservedGoldenImage.localizedDescription
      return
    }
    preferences.selectedImage = name
    activity.append("Using \(name) as the golden image.")
    guard !preferences.isProvisioned(name) else {
      activity.append("\(name) is already provisioned; skipping provisioning.")
      return
    }
    guard !coordinator.isRunning, !imageLibrary.isImageOperationRunning else {
      imageLibrary.errorMessage =
        "\(name) is the golden image but is not provisioned yet. Provision it once the controller and image operations are idle."
      return
    }
    await runProvision(name)
  }

  // Re-provisions the current golden image on demand, even when it is already marked
  // provisioned. Backs the manual Provision toolbar action.
  func provisionGoldenImage() async {
    guard !preferences.selectedImage.isEmpty else {
      imageLibrary.errorMessage = AppConfigurationError.noImageSelected.localizedDescription
      return
    }
    await runProvision(preferences.selectedImage)
  }

  private func runProvision(_ name: String) async {
    guard !coordinator.isRunning else {
      imageLibrary.errorMessage = AppModelError.stopControllerFirst.localizedDescription
      return
    }
    guard !name.hasPrefix(VMName.controllerPrefix) else {
      imageLibrary.errorMessage = AppConfigurationError.reservedGoldenImage.localizedDescription
      return
    }
    guard !imageLibrary.isImageOperationRunning else {
      imageLibrary.errorMessage = AppModelError.imageOperationRunning.localizedDescription
      return
    }
    let task = Task { [weak self] in
      guard let self else { return }
      await performProvision(name)
    }
    provisionTask = task
    provisioningName = name
    await task.value
    provisionTask = nil
    provisioningName = nil
  }

  // stops provisioning and deletes the half set up image, so the next try starts clean.
  func cancelProvisioning() async {
    guard let provisionTask, let name = provisioningName else { return }
    activity.append("Cancelling the setup of \(name).")
    provisionTask.cancel()
    await provisionTask.value
    await imageLibrary.delete(named: name)
  }

  // quitting stops the setup and shuts its vm down cleanly, but keeps the image, since
  // provisioning it again is quicker than downloading it again.
  func stopForShutdown() async {
    guard let provisionTask, let name = provisioningName else { return }
    activity.append("Stopping the setup of \(name) because Forgejo Runner is quitting.")
    provisionTask.cancel()
    await provisionTask.value
  }

  private func performProvision(_ name: String) async {
    imageLibrary.isProvisioningImage = true
    imageLibrary.errorMessage = nil
    imageLibrary.clearOperationOutput()
    activity.append("Provisioning golden image \(name).")
    defer { imageLibrary.isProvisioningImage = false }
    tartConfigurator.configure()
    do {
      try paths.prepare()
      let resources = try ProvisioningResources.bundled()
      let settings = GoldenImageSettings(
        image: name,
        runnerVersion: preferences.runnerVersion,
        xcodeApplicationPath: preferences.xcodeApplicationPath,
        bootTimeoutSeconds: RunnerTimeouts.vmBootSeconds,
        guestAgentTimeoutSeconds: RunnerTimeouts.guestAgentSeconds
      )
      // the pristine image boots behind the same sandbox runner sessions use.
      if let problem = await tart.sandboxStatus().problem {
        throw TartError.sandboxUnavailable(problem)
      }
      try await provisioner.provision(
        settings: settings,
        resources: resources,
        logHandler: { [weak self] message in
          self?.activity.append(message)
          self?.imageLibrary.appendOperationOutput(message + "\n")
        },
        outputHandler: { [weak self] output in
          self?.imageLibrary.appendOperationOutput(output)
        }
      )
      preferences.markProvisioned(name)
      activity.append("Provisioned golden image \(name).")
      await imageLibrary.refresh()
    } catch  where Task.isCancelled {
      activity.append("Cancelled the setup of \(name).")
    } catch {
      imageLibrary.errorMessage = error.localizedDescription
      activity.append("Golden image provisioning failed: \(error.localizedDescription)")
    }
  }
}
