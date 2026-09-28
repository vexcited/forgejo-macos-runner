import Darwin
import Foundation

@MainActor
final class ProcessExecutor: CommandExecuting {
  private let defaultTerminationGracePeriod: Duration
  private var processes: [UUID: Process] = [:]
  private var terminationGracePeriods: [UUID: Duration] = [:]
  private var timeoutTasks: [UUID: Task<Void, Never>] = [:]
  private var terminationTasks: [UUID: Task<Void, Never>] = [:]
  private var timedOut: Set<UUID> = []

  // records every command run, when set by the app.
  var commandLog: CommandLog?

  init(terminationGracePeriod: Duration = .seconds(5)) {
    defaultTerminationGracePeriod = terminationGracePeriod
  }

  func run(
    _ request: CommandRequest,
    timeout: Duration? = nil,
    outputHandler: (@MainActor @Sendable (String) -> Void)? = nil
  ) async throws -> CommandResult {
    try Task.checkCancellation()
    let commandLog = request.isLogged ? commandLog : nil
    commandLog?.willRun(request)
    let commandStarted = ContinuousClock.now
    let identifier = UUID()
    let process = Process()
    let outputPipe = Pipe()
    process.executableURL = request.executableURL
    if let workingDirectory = request.workingDirectory {
      process.currentDirectoryURL = workingDirectory
    }
    process.arguments = request.arguments
    process.environment = request.environment
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    var inputPipe: Pipe?
    if request.standardInput != nil {
      let pipe = Pipe()
      process.standardInput = pipe
      inputPipe = pipe
    } else {
      process.standardInput = FileHandle.nullDevice
    }

    let outputTask = Task.detached {
      await ProcessOutputReader.read(
        from: outputPipe.fileHandleForReading,
        limit: request.outputLimitBytes,
        handler: outputHandler
      )
    }
    var inputError: Error?
    let status = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        process.terminationHandler = { [weak self] finishedProcess in
          let status = finishedProcess.terminationStatus
          Task { @MainActor in
            self?.finish(identifier)
            continuation.resume(returning: status)
          }
        }
        processes[identifier] = process
        terminationGracePeriods[identifier] =
          request.terminationGracePeriod
          ?? defaultTerminationGracePeriod
        do {
          try process.run()
        } catch {
          finish(identifier)
          try? outputPipe.fileHandleForWriting.close()
          try? outputPipe.fileHandleForReading.close()
          outputTask.cancel()
          continuation.resume(throwing: error)
          return
        }

        try? outputPipe.fileHandleForWriting.close()
        if let data = request.standardInput, let inputPipe {
          do {
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
            try inputPipe.fileHandleForWriting.close()
          } catch {
            inputError = error
            requestTermination(identifier)
          }
        }
        beginTimeout(timeout, for: identifier)
      }
    } onCancel: {
      Task { @MainActor [weak self] in
        self?.requestTermination(identifier)
      }
    }

    let output = await outputTask.value
    commandLog?.didFinish(
      executable: request.executableURL.lastPathComponent,
      status: status,
      duration: commandStarted.duration(to: .now)
    )
    if let inputError {
      throw inputError
    }
    if timedOut.remove(identifier) != nil {
      throw CommandExecutionError.timedOut(request.executableURL.lastPathComponent)
    }
    try Task.checkCancellation()
    return CommandResult(status: status, output: output)
  }

  func terminateAll() {
    for identifier in Array(processes.keys) {
      requestTermination(identifier)
    }
  }

  func terminateAllAndWait(timeout: Duration = .seconds(50)) async {
    terminateAll()
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !processes.isEmpty, clock.now < deadline {
      do {
        try await Task.sleep(for: .milliseconds(100))
      } catch {
        break
      }
    }
    for process in processes.values where process.isRunning {
      Darwin.kill(process.processIdentifier, SIGKILL)
    }
  }

  private func beginTimeout(_ timeout: Duration?, for identifier: UUID) {
    guard let timeout else { return }
    timeoutTasks[identifier] = Task { [weak self] in
      do {
        try await Task.sleep(for: timeout)
      } catch {
        return
      }
      guard let self, let process = self.processes[identifier], process.isRunning else {
        return
      }
      self.timedOut.insert(identifier)
      self.requestTermination(identifier)
    }
  }

  private func requestTermination(_ identifier: UUID) {
    guard let process = processes[identifier], process.isRunning else { return }
    process.terminate()
    guard terminationTasks[identifier] == nil else { return }
    let processIdentifier = process.processIdentifier
    let gracePeriod = terminationGracePeriods[identifier] ?? defaultTerminationGracePeriod
    terminationTasks[identifier] = Task { [weak self] in
      guard let self else { return }
      do {
        try await Task.sleep(for: gracePeriod)
      } catch {
        return
      }
      guard let activeProcess = self.processes[identifier],
        activeProcess === process,
        activeProcess.isRunning
      else {
        return
      }
      Darwin.kill(processIdentifier, SIGKILL)
    }
  }

  private func finish(_ identifier: UUID) {
    timeoutTasks.removeValue(forKey: identifier)?.cancel()
    terminationTasks.removeValue(forKey: identifier)?.cancel()
    terminationGracePeriods.removeValue(forKey: identifier)
    processes.removeValue(forKey: identifier)
  }
}
