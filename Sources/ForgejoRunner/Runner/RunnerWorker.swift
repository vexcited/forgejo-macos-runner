import Foundation
import Security

@MainActor
final class RunnerWorker {
  private let tart: TartControlling
  private let ssh: SSHControlling
  private let brokerIdentity: @MainActor () async throws -> SecIdentity
  private let statusHandler: @MainActor @Sendable (WorkerPhase) -> Void
  private let logHandler: @MainActor @Sendable (String) -> Void
  private let guestPreparer: GuestSandboxPreparer
  private let jobRunner: BrokeredJobRunner
  private let vmCleaner: SessionVMCleaner
  private let outputTail = RunnerOutputTail()
  private var api: ForgejoRunnerAPI?
  // the public networks the running session vm is blocked from, so the controller can
  // recycle an idle session once this mac moves to another network.
  private(set) var sessionBlocks: Set<String>?
  private var reportedUnknownRouterAddress = false

  init(
    tart: TartControlling,
    ssh: SSHControlling,
    brokerIdentity: @escaping @MainActor () async throws -> SecIdentity,
    statusHandler: @escaping @MainActor @Sendable (WorkerPhase) -> Void,
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) {
    self.tart = tart
    self.ssh = ssh
    self.brokerIdentity = brokerIdentity
    self.statusHandler = statusHandler
    self.logHandler = logHandler
    guestPreparer = GuestSandboxPreparer(tart: tart)
    jobRunner = BrokeredJobRunner(ssh: ssh, logHandler: logHandler)
    vmCleaner = SessionVMCleaner(tart: tart, logHandler: logHandler)
  }

  func runOneSession(connections: [RunnerConnection], settings: RunnerSettings) async throws {
    guard !connections.isEmpty else { throw RunnerWorkerError.noConnections }
    let resolvedConnections = Self.resolve(connections)
    let vmName = VMName.make(prefix: settings.vmPrefix, connectionName: "pool")
    let sessionDeadline = ContinuousClock.now.advanced(
      by: .seconds(settings.runnerSessionTimeoutSeconds))
    var sessionError: Error?
    var cloneWasAttempted = false
    var tartRunTask: Task<CommandResult, Error>?
    outputTail.reset()

    do {
      let sandbox = await HostAddresses.sandboxBlocks()
      let blocks = sandbox.networks
      if !sandbox.routerAddressKnown, !reportedUnknownRouterAddress {
        reportedUnknownRouterAddress = true
        logHandler(
          "The router did not report its public address over NAT-PMP or UPnP, so the VMs cannot be kept from reaching this network back through it."
        )
      }
      statusHandler(.cloning)
      logHandler(
        "Cloning \(settings.goldenImage) into \(vmName) for \(connections.count) server connection\(connections.count == 1 ? "" : "s")."
      )
      cloneWasAttempted = true
      try await tart.clone(source: settings.goldenImage, name: vmName, outputHandler: nil)

      statusHandler(.booting)
      logHandler("Booting \(vmName).")
      sessionBlocks = blocks
      tartRunTask = Task {
        try await tart.runVM(
          name: vmName, networkMode: .sandboxed(blockedNetworks: Array(blocks)),
          outputHandler: nil)
      }

      let ipAddress = try await tart.waitForIPAddress(
        name: vmName,
        timeoutSeconds: settings.bootTimeoutSeconds
      )
      statusHandler(.waitingForSSH)
      logHandler("Preparing the sandbox of \(vmName) through the Tart guest agent.")
      let hostKey = try await guestPreparer.prepare(
        vmName, dnsServers: settings.dnsServers,
        timeout: .seconds(settings.bootTimeoutSeconds))
      try ssh.trustSessionHostKey(hostKey)
      logHandler("Waiting for key-only SSH on \(vmName) at \(ipAddress).")
      try await ssh.waitUntilReady(
        ipAddress: ipAddress,
        timeout: .seconds(settings.sshTimeoutSeconds)
      )
      try await ssh.validateGuest(ipAddress: ipAddress)

      let identity = try await brokerIdentity()
      let api = forgejoAPI(runnerVersion: settings.runnerVersion)
      let poller = TaskPoller(
        api: api, runnerVersion: settings.runnerVersion, logHandler: logHandler)

      statusHandler(.waitingForJob)
      logHandler(
        "\(vmName) is ready. Waiting for a job across \(connections.count) server connection\(connections.count == 1 ? "" : "s")."
      )
      guard
        let assignment = try await poller.waitForTask(
          connections: resolvedConnections, until: sessionDeadline)
      else {
        logHandler("No job arrived within the runner session limit, recycling \(vmName).")
        throw RunnerWorkerError.sessionIdle
      }

      statusHandler(.runningJob)
      logHandler(
        "Received task \(assignment.taskID) from \(assignment.connection.connection.name), running it in \(vmName)."
      )
      try await jobRunner.run(
        assignment, api: api, identity: identity, poller: poller,
        ipAddress: ipAddress, deadline: sessionDeadline,
        outputHandler: { [weak self] output in
          self?.outputTail.append(output)
        })
      logHandler("The runner pool completed its job.")
    } catch RunnerWorkerError.sessionIdle {
      sessionError = nil
    } catch SSHError.outdatedGuestHelper {
      sessionError = RunnerWorkerError.guestHelperOutdated
    } catch let failure as CommandFailure where failure.status == 64 {
      // the helper rejects --prepare when it predates it, see GuestSandboxPreparer.
      sessionError = RunnerWorkerError.guestHelperOutdated
    } catch {
      sessionError = error
      outputTail.logFailure(redacting: resolvedConnections, to: logHandler)
    }

    ssh.forgetSessionHostKey()
    sessionBlocks = nil
    if cloneWasAttempted {
      statusHandler(.cleaning)
      let cleanupSucceeded = await Task { @MainActor in
        await self.vmCleaner.cleanup(
          vmName: vmName,
          tartRunTask: tartRunTask
        )
      }.value
      if !cleanupSucceeded {
        throw RunnerWorkerError.cleanupFailed(vmName)
      }
    }

    if let sessionError {
      throw sessionError
    }
    try Task.checkCancellation()
  }

  private func forgejoAPI(runnerVersion: String) -> ForgejoRunnerAPI {
    if let api, api.userAgent == "forgejo-runner/v\(runnerVersion)" {
      return api
    }
    let created = ForgejoRunnerAPI(runnerVersion: runnerVersion)
    api = created
    return created
  }
}
