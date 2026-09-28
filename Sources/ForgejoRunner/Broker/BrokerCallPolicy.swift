import Foundation

// decides what each runner call of the guest gets: the task the host already fetched,
// once, and reports forwarded to forgejo only for that task.
@MainActor
final class BrokerCallPolicy {
  private let assignment: TaskAssignment
  private let api: ForgejoRunnerAPI
  private let refusals: BrokerRefusalLog
  private let logHandler: @MainActor @Sendable (String) -> Void
  private var taskDelivered = false

  // true once forgejo accepted a final result for the task.
  private(set) var taskFinished = false

  init(
    assignment: TaskAssignment,
    api: ForgejoRunnerAPI,
    refusals: BrokerRefusalLog,
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) {
    self.assignment = assignment
    self.api = api
    self.refusals = refusals
    self.logHandler = logHandler
  }

  func respond(to request: BrokerHTTP.Request) async -> Data {
    let connection = assignment.connection.connection
    let prefix = connection.basePath + "/api/actions/"
    let runner = ForgejoRunnerAPI.runnerService
    guard request.method == "POST", request.target.hasPrefix(prefix) else {
      return refused("The broker blocked a request outside the runner service.")
    }
    // only binary protobuf calls, so the broker reads the same message forgejo does.
    guard request.headers["content-type"] == "application/proto",
      request.headers["content-encoding"].map({ $0 == "identity" }) ?? true
    else {
      return refused("The broker blocked a runner call that is not plain protobuf.")
    }
    let call = String(request.target.dropFirst(prefix.count))

    switch call {
    case "\(runner)/FetchTask":
      // the task was fetched on the host, the guest gets it once and nothing after.
      guard !taskDelivered else {
        return BrokerHTTP.response(status: 200, contentType: "application/proto")
      }
      taskDelivered = true
      logHandler("Handed task \(assignment.taskID) to the guest runner.")
      return BrokerHTTP.response(
        status: 200, contentType: "application/proto", body: assignment.fetchResponse)

    case "\(runner)/Declare":
      // the host already declared the labels, and the guest must not change them.
      return BrokerHTTP.response(status: 200, contentType: "application/proto")

    case "\(runner)/UpdateTask":
      guard let state = RunnerProtobuf.taskState(inUpdateTask: request.body),
        state.id == assignment.taskID
      else { return refusedForeignTask() }
      let response = await forward(request)
      // forgejo's answer is the authority on whether the task is closed.
      if response.status == 200,
        let accepted = RunnerProtobuf.taskState(inUpdateTask: response.body),
        accepted.id == assignment.taskID, accepted.result != 0
      {
        taskFinished = true
      }
      return response.data

    case "\(runner)/UpdateLog", "\(runner)/UpdateStepSummary":
      guard RunnerProtobuf.taskID(inTaskScopedRequest: request.body) == assignment.taskID else {
        return refusedForeignTask()
      }
      return await forward(request).data

    default:
      return refused("The broker blocked the runner call \(call).")
    }
  }

  private func refusedForeignTask() -> Data {
    refused("The broker refused a runner call for a task other than \(assignment.taskID).")
  }

  private func refused(_ message: String) -> Data {
    refusals.log(message)
    return BrokerHTTP.connectError(
      status: 403, code: "permission_denied", message: "blocked by the runner broker")
  }

  private func forward(_ request: BrokerHTTP.Request) async -> (
    status: Int, body: Data, data: Data
  ) {
    var headers = ["Content-Type": "application/proto", "Connect-Protocol-Version": "1"]
    if let timeout = request.headers["connect-timeout-ms"],
      timeout.count <= 10, timeout.allSatisfy(\.isASCII), timeout.allSatisfy(\.isNumber)
    {
      headers["Connect-Timeout-Ms"] = timeout
    }
    if let key = request.headers["x-runner-request-key"], let uuid = UUID(uuidString: key) {
      headers["x-runner-request-key"] = uuid.uuidString.lowercased()
    }
    do {
      let response = try await api.send(
        path: request.target, headers: headers, body: request.body,
        connection: assignment.connection)
      let contentType = response.contentType.flatMap {
        ["application/proto", "application/json"].contains($0) ? $0 : nil
      }
      return (
        response.status, response.body,
        BrokerHTTP.response(status: response.status, contentType: contentType, body: response.body)
      )
    } catch {
      return (
        502, Data(),
        BrokerHTTP.connectError(
          status: 502, code: "unavailable", message: "forgejo is unreachable from the host")
      )
    }
  }
}
