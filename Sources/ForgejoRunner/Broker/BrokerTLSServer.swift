import Foundation
import Network

// the tls end of each tunnel, where the broker reads the runner calls of the guest one
// at a time and answers them through the call policy.
@MainActor
final class BrokerTLSServer {
  private let connections: BrokerConnections
  private let policy: BrokerCallPolicy

  init(connections: BrokerConnections, policy: BrokerCallPolicy) {
    self.connections = connections
    self.policy = policy
  }

  func accept(_ connection: NWConnection) {
    guard !connections.isStopped, connections.makeRoom() else {
      connection.cancel()
      return
    }
    connections.track(connection, pending: false)
    connection.start(queue: .main)
    readRequest(connection, buffer: BrokerReceiveBuffer())
  }

  // one request at a time: nothing more is read while a request is being answered.
  private func readRequest(_ connection: NWConnection, buffer: BrokerReceiveBuffer) {
    if case .request(let request, let consumed) = BrokerHTTP.parse(buffer.data) {
      buffer.data = Data(buffer.data.dropFirst(consumed))
      serve(connection, request: request, buffer: buffer)
      return
    }
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
      [weak self] data, _, isComplete, error in
      MainActor.assumeIsolated {
        guard let self else { return }
        if let data { buffer.data.append(data) }
        switch BrokerHTTP.parse(buffer.data) {
        case .incomplete where error == nil && !isComplete:
          self.readRequest(connection, buffer: buffer)
        case .request(let request, let consumed):
          buffer.data = Data(buffer.data.dropFirst(consumed))
          self.serve(connection, request: request, buffer: buffer)
        case .invalid:
          self.connections.reply(connection, BrokerHTTP.response(status: 400, close: true))
        default:
          self.connections.finish(connection)
        }
      }
    }
  }

  private func serve(
    _ connection: NWConnection, request: BrokerHTTP.Request, buffer: BrokerReceiveBuffer
  ) {
    guard !connections.isStopped else {
      connections.finish(connection)
      return
    }
    Task { [weak self] in
      guard let response = await self?.policy.respond(to: request),
        self?.connections.isStopped == false
      else {
        return
      }
      connection.send(
        content: response,
        completion: .contentProcessed { [weak self] error in
          MainActor.assumeIsolated {
            guard let self else { return }
            if error == nil {
              self.readRequest(connection, buffer: buffer)
            } else {
              self.connections.finish(connection)
            }
          }
        })
    }
  }
}
