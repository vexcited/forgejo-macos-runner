import Foundation

@MainActor
protocol TartControlling: AnyObject {
  func clone(
    source: String,
    name: String,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws
  func runVM(
    name: String,
    networkMode: TartNetworkMode,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult
  func waitForIPAddress(name: String, timeoutSeconds: Int) async throws -> String
  func stop(name: String, timeoutSeconds: Int) async throws
  func delete(name: String) async throws
  func containsImage(named name: String) async throws -> Bool
  func execute(
    name: String,
    arguments: [String],
    standardInput: Data?,
    timeout: Duration,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult
}

extension TartClient: TartControlling {
}
