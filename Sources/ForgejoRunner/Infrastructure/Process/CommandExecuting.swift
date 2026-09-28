import Foundation

@MainActor
protocol CommandExecuting: AnyObject {
  func run(
    _ request: CommandRequest,
    timeout: Duration?,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult
}
