import Foundation
import GuestKit

// runs the helper's --prepare step as root through the tart guest agent, a virtio
// channel no network peer can reach, and returns the fresh ssh host key it made.
@MainActor
final class GuestSandboxPreparer {
  private let tart: TartControlling

  init(tart: TartControlling) {
    self.tart = tart
  }

  func prepare(
    _ vmName: String, dnsServers: [String], timeout: Duration
  ) async throws -> String {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    var lastError: Error?
    while ContinuousClock.now < deadline {
      try Task.checkCancellation()
      do {
        let result = try await tart.execute(
          name: vmName,
          arguments: ["sudo", "-n", "/usr/local/libexec/forgejo-one-job", "--prepare"]
            + dnsServers,
          standardInput: nil,
          timeout: .seconds(60),
          outputHandler: nil
        )
        guard let hostKey = SessionPreparation.hostKey(inOutput: result.outputString) else {
          throw RunnerWorkerError.preparationFailed("the guest did not report a host key")
        }
        return hostKey
      } catch let failure as CommandFailure where failure.status == 64 {
        throw failure
      } catch let error as RunnerWorkerError {
        throw error
      } catch {
        // the guest agent starts a little after the vm gets its address.
        lastError = error
      }
      try await Task.sleep(for: .seconds(2))
    }
    throw RunnerWorkerError.preparationFailed(
      lastError?.localizedDescription ?? "the tart guest agent did not answer")
  }
}
