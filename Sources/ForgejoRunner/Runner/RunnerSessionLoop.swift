import Foundation

// runs runner sessions back to back until cancelled, backing off after failures.
@MainActor
final class RunnerSessionLoop {
  private static let maxRetryDelaySeconds = 300.0
  private let worker: RunnerWorker
  private let network: NetworkMonitor
  private let staleVMs: StaleVMCleaner
  private let log: ActivityLog
  private let statusHandler: @MainActor @Sendable (WorkerPhase, String?) -> Void
  private let isStopping: @MainActor @Sendable () -> Bool
  private let fatalErrorHandler: @MainActor @Sendable (RunnerWorkerError) -> Void
  private(set) var sessionTask: Task<Void, Error>?

  init(
    worker: RunnerWorker,
    network: NetworkMonitor,
    staleVMs: StaleVMCleaner,
    log: ActivityLog,
    statusHandler: @escaping @MainActor @Sendable (WorkerPhase, String?) -> Void,
    isStopping: @escaping @MainActor @Sendable () -> Bool,
    fatalErrorHandler: @escaping @MainActor @Sendable (RunnerWorkerError) -> Void
  ) {
    self.worker = worker
    self.network = network
    self.staleVMs = staleVMs
    self.log = log
    self.statusHandler = statusHandler
    self.isStopping = isStopping
    self.fatalErrorHandler = fatalErrorHandler
  }

  func run(connections: [RunnerConnection], settings: RunnerSettings) async {
    let worker = self.worker
    let baseDelay = Double(max(settings.retryDelaySeconds, 1))
    var delay = baseDelay
    var failures = 0
    while !Task.isCancelled {
      // never spend a VM clone while offline; wait for a path and resume when it returns.
      await waitForNetwork()
      if Task.isCancelled { break }
      // never run two VMs against the same runner identity: make sure any previous
      // disposable VM is gone before cloning a new one, retrying until it is.
      await ensureNoStaleVMs(goldenImage: settings.goldenImage)
      if Task.isCancelled { break }

      let session = Task {
        try await worker.runOneSession(connections: connections, settings: settings)
      }
      sessionTask = session
      do {
        try await session.value
        delay = baseDelay
        failures = 0
      } catch is CancellationError {
        sessionTask = nil
        if isStopping() || Task.isCancelled { break }
        // a wake or reconnect cancelled just this session; start a fresh one now.
        log.append("Restarting the runner session to reconnect.")
        delay = baseDelay
        failures = 0
        continue
      } catch let error as RunnerWorkerError where error.isFatal {
        sessionTask = nil
        fatalErrorHandler(error)
        break
      } catch {
        sessionTask = nil
        failures += 1
        statusHandler(.retrying, error.localizedDescription)
        log.append(
          "Runner pool failed: \(error.localizedDescription). Retrying in \(Int(delay))s (attempt \(failures))."
        )
        do {
          try await Task.sleep(for: .seconds(delay))
        } catch {
          break
        }
        delay = min(delay * 2, Self.maxRetryDelaySeconds)
      }
      sessionTask = nil
    }
    if isStopping() || Task.isCancelled {
      statusHandler(.stopped, nil)
    }
  }

  // Blocks (cancellably) until the Mac has a usable network path again.
  private func waitForNetwork() async {
    guard !network.isReachable else { return }
    statusHandler(.retrying, "Waiting for a network connection.")
    log.append("No network connection; waiting to resume listening for jobs.")
    while !network.isReachable {
      if Task.isCancelled { return }
      do {
        try await Task.sleep(for: .seconds(3))
      } catch {
        return
      }
    }
    log.append("Network connection restored; resuming.")
  }

  // Keeps trying to remove any leftover disposable VM until none remain, so a new
  // session never starts while a previous VM might still hold the runner identity.
  private func ensureNoStaleVMs(goldenImage: String) async {
    var delay = 5.0
    while !Task.isCancelled {
      do {
        try await staleVMs.removeStaleVMs(prefix: VMName.controllerPrefix, excluding: goldenImage)
        return
      } catch {
        statusHandler(.retrying, "Removing a previous VM before reconnecting.")
        log.append(
          "A previous VM could not be removed yet: \(error.localizedDescription). Retrying in \(Int(delay))s."
        )
        do {
          try await Task.sleep(for: .seconds(delay))
        } catch {
          return
        }
        delay = min(delay * 2, Self.maxRetryDelaySeconds)
      }
    }
  }
}
