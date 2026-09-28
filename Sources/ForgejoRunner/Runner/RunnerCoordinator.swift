import Foundation
import Observation
import Security

@MainActor
@Observable
final class RunnerCoordinator {
  static let poolName = "Runner pool"
  private let tart: TartClient
  private let ssh: SSHClient
  private let brokerIdentity: @MainActor () async throws -> SecIdentity
  private let keepAwake: KeepAwakeTask
  private let wakeObserver = WakeObserver()
  private let network = NetworkMonitor()
  let log: ActivityLog
  private let controllerLock: ControllerLock
  private let staleVMs: StaleVMCleaner
  private let preflight: ControllerPreflight

  private var rootTask: Task<Void, Never>?
  private var workerTask: Task<Void, Never>?
  private var sessionLoop: RunnerSessionLoop?
  private(set) var worker: RunnerWorker?
  private var networkCheckTask: Task<Void, Never>?
  var sessionTask: Task<Void, Error>? { sessionLoop?.sessionTask }

  private(set) var isRunning = false
  private(set) var isPreparing = false
  private(set) var isStopping = false
  private(set) var statuses: [String: WorkerStatus] = [:]
  private(set) var tartVersion = "Not checked"
  var errorMessage: String?

  init(
    tart: TartClient,
    ssh: SSHClient,
    brokerIdentity: @escaping @MainActor () async throws -> SecIdentity,
    caffeine: SleepPreventing,
    log: ActivityLog,
    controllerLock: ControllerLock
  ) {
    self.tart = tart
    self.ssh = ssh
    self.brokerIdentity = brokerIdentity
    keepAwake = KeepAwakeTask(caffeine: caffeine, log: log)
    self.log = log
    self.controllerLock = controllerLock
    staleVMs = StaleVMCleaner(tart: tart, log: log)
    preflight = ControllerPreflight(tart: tart, ssh: ssh, staleVMs: staleVMs)
    network.onChange = { [weak self] in self?.scheduleNetworkCheck() }
    network.start()
  }

  func start(connections: [RunnerConnection], settings: RunnerSettings) {
    guard !isRunning else { return }
    guard !connections.isEmpty else {
      errorMessage = AppConfigurationError.noConnections.localizedDescription
      return
    }
    do {
      try controllerLock.acquire()
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    isRunning = true
    isPreparing = true
    isStopping = false
    errorMessage = nil
    statuses = [
      Self.poolName: WorkerStatus(
        connectionName: Self.poolName,
        phase: .recovering,
        vmName: nil,
        detail: "\(connections.count) configured connection\(connections.count == 1 ? "" : "s")",
        updatedAt: Date()
      )
    ]
    log.append(
      "Starting the runner controller with \(connections.count) connection\(connections.count == 1 ? "" : "s")."
    )
    keepAwake.start(settings)
    wakeObserver.register { [weak self] in
      self?.handleWake()
    }
    rootTask = Task { [weak self] in
      await self?.prepareAndStart(connections: connections, settings: settings)
    }
  }

  func stop() async {
    guard isRunning || isPreparing else { return }
    isStopping = true
    log.append("Stopping the runner controller and cleaning active VMs.")
    rootTask?.cancel()
    sessionTask?.cancel()
    workerTask?.cancel()
    if let workerTask {
      await workerTask.value
    }
    if let rootTask {
      await rootTask.value
    }
    workerTask = nil
    self.rootTask = nil
    isPreparing = false
    isRunning = false
    isStopping = false
    for name in Array(statuses.keys) {
      updateStatus(name: name, phase: .stopped)
    }
    log.append("Runner controller stopped.")
    releaseControllerResources()
  }

  private func prepareAndStart(connections: [RunnerConnection], settings: RunnerSettings) async {
    do {
      tartVersion = try await tart.validateCLI()
      try await preflight.check(goldenImage: settings.goldenImage)
      try Task.checkCancellation()
      isPreparing = false
      try Task.checkCancellation()
      startWorker(connections: connections, settings: settings)
    } catch is CancellationError {
      isPreparing = false
    } catch {
      errorMessage = error.localizedDescription
      log.append("Controller startup failed: \(error.localizedDescription)")
      isPreparing = false
      isRunning = false
      for name in Array(statuses.keys) {
        updateStatus(name: name, phase: .failed, detail: error.localizedDescription)
      }
      releaseControllerResources()
    }
  }

  private func startWorker(connections: [RunnerConnection], settings: RunnerSettings) {
    let worker = RunnerWorker(
      tart: tart,
      ssh: ssh,
      brokerIdentity: brokerIdentity,
      statusHandler: { [weak self] phase in
        self?.updateStatus(name: Self.poolName, phase: phase)
      },
      logHandler: { [weak self] message in
        self?.log.append(message)
      }
    )
    self.worker = worker
    let loop = RunnerSessionLoop(
      worker: worker,
      network: network,
      staleVMs: staleVMs,
      log: log,
      statusHandler: { [weak self] phase, detail in
        self?.updateStatus(name: Self.poolName, phase: phase, detail: detail)
      },
      isStopping: { [weak self] in self?.isStopping ?? false },
      fatalErrorHandler: { [weak self] error in self?.stopAfterFatalError(error) }
    )
    sessionLoop = loop
    workerTask = Task { [weak self] in
      guard let self else { return }
      await loop.run(connections: connections, settings: settings)
      self.workerTask = nil
    }
  }

  private func stopAfterFatalError(_ error: RunnerWorkerError) {
    errorMessage = error.localizedDescription
    updateStatus(name: Self.poolName, phase: .failed, detail: error.localizedDescription)
    log.append("Runner pool stopped: \(error.localizedDescription)")
    finishAfterFailure()
  }

  private func scheduleNetworkCheck() {
    networkCheckTask?.cancel()
    networkCheckTask = Task { [weak self] in
      // path updates come in bursts, and every vm boot adds a bridge interface.
      try? await Task.sleep(for: .seconds(3))
      await self?.recycleIdleSessionAfterNetworkChange()
    }
  }

  private func releaseControllerResources() {
    wakeObserver.remove()
    networkCheckTask?.cancel()
    networkCheckTask = nil
    keepAwake.stop()
    controllerLock.release()
  }

  private func finishAfterFailure() {
    guard !isStopping else { return }
    isRunning = false
    isPreparing = false
    releaseControllerResources()
  }

  private func updateStatus(name: String, phase: WorkerPhase, detail: String? = nil) {
    statuses[name] = WorkerStatus(
      connectionName: name,
      phase: phase,
      vmName: statuses[name]?.vmName,
      detail: detail,
      updatedAt: Date()
    )
  }
}
