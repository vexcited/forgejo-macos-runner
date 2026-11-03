import Foundation
import Observation

// clones tart images and pauses, resumes or cancels a clone in flight.
@MainActor
@Observable
final class ImageCloneController {
  private let imageLibrary: ImageLibrary
  private let tart: TartClient
  private let commands: CommandExecuting
  private let spaceReservation: DownloadSpaceReservation
  private let tartConfigurator: TartConfigurator
  private let preferences: AppPreferences
  private let activity: ActivityLog
  private let coordinator: RunnerCoordinator
  private let pausedClones: PausedCloneController
  private var cloneTask: Task<String?, Never>?
  private var cloneInterruption: CloneInterruption?
  private var tracker = CloneProgressTracker()

  private(set) var activeClone: TartCloneRequest?
  private(set) var cloneProgress: TartCloneProgress?
  private(set) var isInterruptingClone = false
  // set after a clone to ask whether the new image should become the golden image.
  var pendingGoldenPrompt: GoldenImagePrompt?
  // provisions the golden image again once a download replaced it.
  var provisionGoldenImage: (@MainActor (String) async -> Void)?

  init(
    imageLibrary: ImageLibrary,
    tart: TartClient,
    commands: CommandExecuting,
    spaceReservation: DownloadSpaceReservation,
    tartConfigurator: TartConfigurator,
    preferences: AppPreferences,
    activity: ActivityLog,
    coordinator: RunnerCoordinator,
    pausedClones: PausedCloneController
  ) {
    self.imageLibrary = imageLibrary
    self.tart = tart
    self.commands = commands
    self.spaceReservation = spaceReservation
    self.tartConfigurator = tartConfigurator
    self.preferences = preferences
    self.activity = activity
    self.coordinator = coordinator
    self.pausedClones = pausedClones
  }

  func cloneImage(source: String, name: String) async {
    guard pausedClones.pausedClone == nil else {
      imageLibrary.errorMessage = AppModelError.pausedCloneExists.localizedDescription
      return
    }
    await runClone(TartCloneRequest(source: source, name: name), resuming: nil)
  }

  // downloads another version of a local image. the current one stays usable until the
  // new one is complete, unless there is no room for both, then it is deleted first.
  func updateImage(_ name: String, to source: String, keepingCurrent: Bool) async {
    guard pausedClones.pausedClone == nil else {
      imageLibrary.errorMessage = AppModelError.pausedCloneExists.localizedDescription
      return
    }
    guard canStartClone(named: name) else { return }
    if keepingCurrent {
      let request = TartCloneRequest(source: source, name: "\(name)-update", replacing: name)
      await runClone(request, resuming: nil)
      return
    }
    guard await deleteBeforeUpdate(name) else { return }
    await runClone(TartCloneRequest(source: source, name: name), resuming: nil)
  }

  // the golden designation is kept, so the new download is provisioned in its place.
  private func deleteBeforeUpdate(_ name: String) async -> Bool {
    tartConfigurator.configure()
    do {
      if let image = imageLibrary.images.first(where: { $0.name == name }), image.isRunning {
        try await tart.stop(name: name, timeoutSeconds: 30)
      }
      try await tart.delete(name: name)
      preferences.clearProvisioned(name)
      preferences.setOrigin(nil, of: name)
      activity.append("Deleted Tart image \(name) to make room for its update.")
      return true
    } catch {
      imageLibrary.errorMessage = error.localizedDescription
      activity.append("Could not delete \(name) before its update: \(error.localizedDescription)")
      return false
    }
  }

  func resumePausedClone() async {
    guard let pausedClone = pausedClones.pausedClone else { return }
    await runClone(pausedClone.request, resuming: pausedClone)
  }

  func pauseClone() async {
    await interruptClone(.pause)
  }

  func cancelClone() async {
    await interruptClone(.cancel)
  }

  // a download in flight is paused so it can continue after the next launch.
  func pauseForShutdown() async {
    guard imageLibrary.isCloningImage else { return }
    await pauseClone()
    if let cloneTask {
      _ = await cloneTask.value
    }
  }

  private func canStartClone(named name: String) -> Bool {
    guard !coordinator.isRunning else {
      imageLibrary.errorMessage = AppModelError.stopControllerFirst.localizedDescription
      return false
    }
    guard !imageLibrary.isImageOperationRunning else {
      imageLibrary.errorMessage = AppModelError.imageOperationRunning.localizedDescription
      return false
    }
    guard !name.hasPrefix(VMName.controllerPrefix) else {
      imageLibrary.errorMessage = AppModelError.reservedImageName.localizedDescription
      return false
    }
    return true
  }

  private func runClone(_ request: TartCloneRequest, resuming paused: PausedClone?) async {
    guard canStartClone(named: request.name) else { return }
    tartConfigurator.configure()
    imageLibrary.isCloningImage = true
    let task = Task { [weak self] () -> String? in
      guard let self else { return nil }
      return await performClone(request, resuming: paused)
    }
    cloneTask = task
    if let golden = await task.value {
      await provisionGoldenImage?(golden)
    }
  }

  // returns the golden image name when the download replaced it and needs provisioning.
  private func performClone(_ request: TartCloneRequest, resuming paused: PausedClone?) async
    -> String?
  {
    tracker = CloneProgressTracker()
    cloneProgress = tracker.progress
    activeClone = request
    cloneInterruption = nil
    imageLibrary.errorMessage = nil
    imageLibrary.clearOperationOutput()
    if paused == nil {
      activity.append("Cloning Tart image \(request.source) as \(request.name).")
    } else {
      activity.append("Resuming the clone of \(request.source) as \(request.name).")
    }
    let monitor = Task { [weak self, commands] in
      await DownloadTrafficMonitor(commands: commands).run { bytes in
        self?.tracker.record(receivedBytes: bytes, at: .now)
        self?.cloneProgress = self?.tracker.progress
        self?.spaceReservation.update()
      }
    }
    defer {
      monitor.cancel()
      // already released above, this only covers an unexpected exit.
      Task { [spaceReservation] in await spaceReservation.end() }
      imageLibrary.isCloningImage = false
      isInterruptingClone = false
      activeClone = nil
      cloneProgress = nil
      cloneInterruption = nil
      cloneTask = nil
    }
    if let paused {
      do {
        try pausedClones.restore(paused)
      } catch {
        // the kept download stays in app state untouched so resume can be retried.
        imageLibrary.errorMessage = error.localizedDescription
        activity.append("Could not restore the partial download: \(error.localizedDescription)")
        return nil
      }
    }
    guard await reserveSpace(for: request, resuming: paused) else { return nil }
    let origin = await ImageOriginResolver.resolve(source: request.source)
    do {
      try await tart.clone(
        source: request.source,
        name: request.name,
        outputHandler: { [weak self] output in
          guard let self else { return }
          imageLibrary.appendOperationOutput(tracker.consume(output))
          cloneProgress = tracker.progress
        }
      )
      await spaceReservation.end()
      if paused != nil {
        try pausedClones.discardAfterResume()
      }
      let name = try await swapIntoPlace(request)
      // a fresh clone is raw; ask whether to adopt it as the golden image.
      preferences.clearProvisioned(name)
      preferences.setOrigin(origin, of: name)
      activity.append("Cloned Tart image \(name).")
      await imageLibrary.refresh()
      if preferences.selectedImage == name {
        return name
      }
      pendingGoldenPrompt = GoldenImagePrompt(
        imageName: name, useByDefault: preferences.selectedImage.isEmpty)
    } catch is CancellationError {
      await spaceReservation.end()
      let progress = tracker.progress
      if cloneInterruption == .pause {
        pausedClones.keepPartialDownload(for: request, progress: progress, afterFailure: nil)
      } else {
        pausedClones.removePartialDownload(for: request)
        if paused != nil {
          pausedClones.forget()
        }
        activity.append("Cancelled the clone of \(request.name)\(progress.percentSuffix).")
        // this task is cancelled, so the list is refreshed from a fresh one.
        await Task { await imageLibrary.refresh() }.value
      }
    } catch {
      await spaceReservation.end()
      imageLibrary.errorMessage = error.localizedDescription
      activity.append("Image clone failed: \(error.localizedDescription)")
      pausedClones.keepPartialDownload(
        for: request, progress: tracker.reported, afterFailure: error)
      await imageLibrary.refresh()
    }
    return nil
  }

  // an update downloads next to the image it replaces, then takes its name.
  private func swapIntoPlace(_ request: TartCloneRequest) async throws -> String {
    guard let replaced = request.replacing else { return request.name }
    if try await tart.images().first(where: { $0.name == replaced })?.isRunning == true {
      try await tart.stop(name: replaced, timeoutSeconds: 30)
    }
    if try await tart.containsImage(named: replaced) {
      try await tart.delete(name: replaced)
    }
    try await tart.rename(name: request.name, to: replaced)
    activity.append("Replaced Tart image \(replaced) with its update.")
    return replaced
  }

  // holds the space the image needs before tart writes anything.
  private func reserveSpace(for request: TartCloneRequest, resuming paused: PausedClone?) async
    -> Bool
  {
    do {
      if try await spaceReservation.begin(source: request.source) {
        activity.append("Set aside disk space for \(request.name).")
      }
      return true
    } catch {
      activity.append("Did not start \(request.name): \(error.localizedDescription)")
      if paused != nil {
        pausedClones.keepPartialDownload(
          for: request, progress: tracker.reported, afterFailure: error)
      } else {
        imageLibrary.errorMessage = error.localizedDescription
      }
      return false
    }
  }

  private func interruptClone(_ interruption: CloneInterruption) async {
    guard let cloneTask, cloneInterruption == nil else { return }
    cloneInterruption = interruption
    isInterruptingClone = true
    activity.append(
      interruption == .pause ? "Pausing the image clone." : "Cancelling the image clone.")
    cloneTask.cancel()
    _ = await cloneTask.value
  }
}
