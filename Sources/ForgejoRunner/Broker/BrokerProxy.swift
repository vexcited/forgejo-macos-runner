import Foundation
import Network

// the http CONNECT proxy the guest runner reaches through its ssh reverse tunnel. it
// only opens tunnels to forgejo, and each tunnel ends at the tls listener of the broker.
@MainActor
final class BrokerProxy {
  private let connections: BrokerConnections
  private let credentials: BrokerProxyCredentials
  private let refusals: BrokerRefusalLog
  private let forgejoAuthority: String

  init(
    connections: BrokerConnections,
    credentials: BrokerProxyCredentials,
    refusals: BrokerRefusalLog,
    forgejoAuthority: String
  ) {
    self.connections = connections
    self.credentials = credentials
    self.refusals = refusals
    self.forgejoAuthority = forgejoAuthority
  }

  func accept(_ connection: NWConnection, tlsPath: String) {
    guard !connections.isStopped, connections.makeRoom() else {
      connection.cancel()
      return
    }
    connections.track(connection, pending: true)
    connection.start(queue: .main)
    readConnectRequest(connection, buffer: BrokerReceiveBuffer(), tlsPath: tlsPath)
  }

  private func readConnectRequest(
    _ connection: NWConnection, buffer: BrokerReceiveBuffer, tlsPath: String
  ) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
      [weak self] data, _, isComplete, error in
      MainActor.assumeIsolated {
        guard let self else { return }
        if let data { buffer.data.append(data) }
        switch BrokerHTTP.parse(buffer.data, headOnly: true) {
        case .incomplete where error == nil && !isComplete:
          self.readConnectRequest(connection, buffer: buffer, tlsPath: tlsPath)
        case .request(let request, let consumed):
          self.openTunnel(
            connection, request: request, leftover: Data(buffer.data.dropFirst(consumed)),
            tlsPath: tlsPath)
        default:
          self.connections.finish(connection)
        }
      }
    }
  }

  private func openTunnel(
    _ connection: NWConnection, request: BrokerHTTP.Request, leftover: Data, tlsPath: String
  ) {
    guard request.method == "CONNECT" else {
      connections.reply(connection, BrokerHTTP.response(status: 405, close: true))
      return
    }
    guard credentials.accepts(request.headers["proxy-authorization"]) else {
      connections.reply(connection, BrokerHTTP.response(status: 407, close: true))
      return
    }
    guard request.target.lowercased() == forgejoAuthority else {
      refusals.log("The broker refused a tunnel to \(request.target).")
      connections.reply(connection, BrokerHTTP.response(status: 403, close: true))
      return
    }
    connections.markVerified(connection)
    guard connections.makeRoom() else {
      connections.finish(connection)
      return
    }

    let upstream = NWConnection(to: .unix(path: tlsPath), using: .tcp)
    connections.track(upstream, pending: false)
    upstream.stateUpdateHandler = { [weak self] state in
      MainActor.assumeIsolated {
        guard let self else { return }
        switch state {
        case .ready:
          guard !self.connections.isStopped else {
            self.connections.finish(connection)
            self.connections.finish(upstream)
            return
          }
          connection.send(
            content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8),
            completion: .contentProcessed { _ in })
          if !leftover.isEmpty {
            upstream.send(content: leftover, completion: .contentProcessed { _ in })
          }
          self.pump(from: connection, to: upstream)
          self.pump(from: upstream, to: connection)
        case .failed, .cancelled:
          self.connections.finish(connection)
          self.connections.finish(upstream)
        default:
          break
        }
      }
    }
    upstream.start(queue: .main)
  }

  // reads the next chunk only once the previous one was handed to the other side, so a
  // guest that sends faster than the broker forwards cannot grow the app's memory.
  private func pump(from source: NWConnection, to destination: NWConnection) {
    source.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
      [weak self] data, _, isComplete, error in
      MainActor.assumeIsolated {
        guard let self else { return }
        let ended = isComplete || error != nil
        guard let data, !data.isEmpty else {
          if ended {
            self.connections.finish(source)
            self.connections.finish(destination)
          } else {
            self.pump(from: source, to: destination)
          }
          return
        }
        destination.send(
          content: data,
          completion: .contentProcessed { [weak self] sendError in
            MainActor.assumeIsolated {
              guard let self else { return }
              if ended || sendError != nil {
                self.connections.finish(source)
                self.connections.finish(destination)
              } else {
                self.pump(from: source, to: destination)
              }
            }
          })
      }
    }
  }
}
