import Foundation

extension CommandExecuting {
  // runs the request and throws a CommandFailure when it exits with a nonzero status.
  func checked(
    _ request: CommandRequest,
    timeout: Duration?,
    outputHandler: (@MainActor @Sendable (String) -> Void)? = nil
  ) async throws -> CommandResult {
    let result = try await run(request, timeout: timeout, outputHandler: outputHandler)
    guard result.status == 0 else {
      throw CommandFailure(
        executable: request.executableURL.lastPathComponent,
        status: result.status,
        output: result.outputString
      )
    }
    return result
  }
}
