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
  private var cloneTask: Task<Void, Never>?
  private var cloneInterruption: CloneInterruption?
  private var tracker = CloneProgressTracker()

  private(set) var activeClone: TartCloneRequest?
  private(set) var cloneProgress: TartCloneProgress?
  private(set) var isInterruptingClone = false
  // set after a clone to ask whether the new image should become the golden image.
  var pendingGoldenPrompt: GoldenImagePrompt?

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
      await cloneTask.value
    }
  }

  private func runClone(_ request: TartCloneRequest, resuming paused: PausedClone?) async {
    guard !coordinator.isRunning else {
      imageLibrary.errorMessage = AppModelError.stopControllerFirst.localizedDescription
      return
    }
    guard !imageLibrary.isImageOperationRunning else {
      imageLibrary.errorMessage = AppModelError.imageOperationRunning.localizedDescription
      return
    }
    guard !request.name.hasPrefix(VMName.controllerPrefix) else {
      imageLibrary.errorMessage = AppModelError.reservedImageName.localizedDescription
      return
    }
    tartConfigurator.configure()
    imageLibrary.isCloningImage = true
    let task = Task { [weak self] in
      guard let self else { return }
      await performClone(request, resuming: paused)
    }
    cloneTask = task
    await task.value
  }

  private func performClone(_ request: TartCloneRequest, resuming paused: PausedClone?) async {
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
        return
      }
    }
    guard await reserveSpace(for: request, resuming: paused) else { return }
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
      // a fresh clone is raw; ask whether to adopt it as the golden image.
      preferences.clearProvisioned(request.name)
      activity.append("Cloned Tart image \(request.name).")
      await imageLibrary.refresh()
      pendingGoldenPrompt = GoldenImagePrompt(
        imageName: request.name, useByDefault: preferences.selectedImage.isEmpty)
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
    await cloneTask.value
  }
}
