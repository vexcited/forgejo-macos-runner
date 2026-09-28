import Foundation

extension AppModel {
  // quitting stops everything in order: a download is paused, image setup and the runner
  // stop their vms cleanly, then whatever process is left is ended. it never takes longer
  // than the grace period, after which the remaining processes are ended anyway.
  func shutdown() async {
    let graceful = Task { await stopForShutdown() }
    if await !Self.finishes(graceful, within: .seconds(120)) {
      activity.append("Stopping took too long, ending the remaining processes.")
    }
    await commands.terminateAllAndWait()
  }

  private func stopForShutdown() async {
    await imageClones.pauseForShutdown()
    await goldenImages.stopForShutdown()
    await coordinator.stop()
  }

  private static func finishes(_ task: Task<Void, Never>, within limit: Duration) async -> Bool {
    let once = OneShot()
    return await withCheckedContinuation { continuation in
      Task {
        await task.value
        if once.claim() { continuation.resume(returning: true) }
      }
      Task {
        try? await Task.sleep(for: limit)
        if once.claim() { continuation.resume(returning: false) }
      }
    }
  }
}
