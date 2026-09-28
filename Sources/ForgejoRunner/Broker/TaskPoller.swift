import Foundation

// waits for one job across every connection from this mac, so a runner token is never
// needed inside the vm to find work.
@MainActor
final class TaskPoller {
  private let api: ForgejoRunnerAPI
  private let runnerVersion: String
  private let logHandler: @MainActor @Sendable (String) -> Void

  init(
    api: ForgejoRunnerAPI,
    runnerVersion: String,
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) {
    self.api = api
    self.runnerVersion = runnerVersion
    self.logHandler = logHandler
  }

  // nil when the deadline passes without a job.
  func waitForTask(
    connections: [ResolvedRunnerConnection],
    until deadline: ContinuousClock.Instant,
    interval: Duration = .seconds(2)
  ) async throws -> TaskAssignment? {
    for connection in connections {
      _ = try await api.call(
        "Declare",
        // forgejo-runner declares label names without their :host suffix.
        body: RunnerProtobuf.declareRequest(
          version: "v\(runnerVersion)", labels: connection.connection.labelNames),
        connection: connection
      )
    }

    // a request key is kept until forgejo answers, so a retried fetch whose first
    // answer was lost returns the same task instead of stranding it.
    var requestKeys = connections.map { _ in UUID() }
    var reportedFailures: Set<String> = []
    while ContinuousClock.now < deadline {
      for (index, connection) in connections.enumerated() {
        try Task.checkCancellation()
        let response: Data
        do {
          response = try await api.call(
            "FetchTask", body: Data(), connection: connection, requestKey: requestKeys[index])
        } catch let error as CancellationError {
          throw error
        } catch {
          if reportedFailures.insert(connection.connection.name).inserted {
            logHandler(
              "Could not ask \(connection.connection.name) for a job: \(error.localizedDescription)"
            )
          }
          continue
        }
        requestKeys[index] = UUID()
        reportedFailures.remove(connection.connection.name)
        guard let taskID = RunnerProtobuf.taskID(inFetchTaskResponse: response) else { continue }
        // the broker matches guest reports against this id, so it must be a real one.
        guard taskID > 0 else {
          throw TaskPollerError.invalidTask(connection.connection.name)
        }
        guard !RunnerProtobuf.hasAdditionalTasks(inFetchTaskResponse: response) else {
          throw TaskPollerError.unexpectedAdditionalTasks(connection.connection.name)
        }
        return TaskAssignment(connection: connection, taskID: taskID, fetchResponse: response)
      }
      try await Task.sleep(for: interval)
    }
    return nil
  }

  // closes a task the guest never finished, so forgejo does not wait for it to time out.
  func failTask(_ assignment: TaskAssignment) async {
    do {
      _ = try await api.call(
        "UpdateTask",
        body: RunnerProtobuf.failedTaskRequest(taskID: assignment.taskID, stoppedAt: Date()),
        connection: assignment.connection
      )
      logHandler("Marked task \(assignment.taskID) as failed in Forgejo.")
    } catch {
      logHandler(
        "Could not mark task \(assignment.taskID) as failed: \(error.localizedDescription)")
    }
  }
}
