import Foundation

// The subset of Tart the provisioner drives; TartClient satisfies it.
@MainActor
protocol TartProvisioning: AnyObject {
  func images() async throws -> [TartImage]
  func runVM(
    name: String,
    networkMode: TartNetworkMode,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult
  func waitForIPAddress(name: String, timeoutSeconds: Int) async throws -> String
  func stop(name: String, timeoutSeconds: Int) async throws
  func execute(
    name: String,
    arguments: [String],
    standardInput: Data?,
    timeout: Duration,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws -> CommandResult
}

extension TartClient: TartProvisioning {}
