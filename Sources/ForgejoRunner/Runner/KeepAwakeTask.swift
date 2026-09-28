import Foundation

// keeps this mac awake while the controller listens, when the settings ask for it.
@MainActor
final class KeepAwakeTask {
  private let caffeine: SleepPreventing
  private let log: ActivityLog
  private var task: Task<Void, Never>?

  init(caffeine: SleepPreventing, log: ActivityLog) {
    self.caffeine = caffeine
    self.log = log
  }

  func start(_ settings: RunnerSettings) {
    guard settings.preventSleep else { return }
    log.append("Keeping this Mac awake while the controller is listening.")
    task = Task { [weak self] in
      guard let self else { return }
      do {
        try await self.caffeine.run()
      } catch is CancellationError {
      } catch {
        self.log.append("The keep-awake helper stopped: \(error.localizedDescription)")
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }
}
