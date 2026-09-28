import Foundation
import Network
import Security

// opens the unix socket listeners of the broker on the main queue.
@MainActor
enum BrokerListener {
  static func tlsParameters(identity: SecIdentity) throws -> NWParameters {
    let tlsOptions = NWProtocolTLS.Options()
    let security = tlsOptions.securityProtocolOptions
    guard let secIdentity = sec_identity_create(identity) else {
      throw RunnerBrokerError.identityUnavailable
    }
    sec_protocol_options_set_local_identity(security, secIdentity)
    sec_protocol_options_set_min_tls_protocol_version(security, .TLSv12)
    sec_protocol_options_add_tls_application_protocol(security, "http/1.1")
    return NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
  }

  static func start(
    parameters: NWParameters,
    path: String,
    handler: @escaping @MainActor (NWConnection) -> Void
  ) async throws -> NWListener {
    parameters.requiredLocalEndpoint = .unix(path: path)
    let listener = try NWListener(using: parameters)
    listener.newConnectionHandler = { connection in
      MainActor.assumeIsolated { handler(connection) }
    }
    try await ready(listener)
    return listener
  }

  private static func ready(_ listener: NWListener) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      var resumed = false
      listener.stateUpdateHandler = { state in
        MainActor.assumeIsolated {
          guard !resumed else { return }
          switch state {
          case .ready:
            resumed = true
            continuation.resume()
          case .failed(let error):
            resumed = true
            continuation.resume(throwing: RunnerBrokerError.listenerFailed("\(error)"))
          case .cancelled:
            resumed = true
            continuation.resume(throwing: RunnerBrokerError.listenerFailed("cancelled"))
          default:
            break
          }
        }
      }
      listener.start(queue: .main)
    }
  }
}
