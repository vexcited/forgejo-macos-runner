import Foundation
import Network

// every open connection of one broker, with the slot limit and the deadline for
// proxy connections that have not sent a valid CONNECT yet.
@MainActor
final class BrokerConnections {
  private static let maximumConnections = 16
  // how long a proxy connection may stay open before it sends a valid CONNECT.
  private static let verificationTimeout = DispatchTimeInterval.seconds(10)

  private var connections: [ObjectIdentifier: NWConnection] = [:]
  // proxy connections that have not sent a valid CONNECT yet, oldest first.
  private var pending: [ObjectIdentifier] = []

  private(set) var isStopped = false

  func stop() {
    isStopped = true
    for connection in connections.values {
      connection.cancel()
    }
    connections.removeAll()
    pending.removeAll()
  }

  // a pending connection is closed after verificationTimeout, so connections that
  // never send a valid CONNECT cannot hold the connection slots.
  func track(_ connection: NWConnection, pending isPending: Bool) {
    let id = ObjectIdentifier(connection)
    connections[id] = connection
    guard isPending else { return }
    pending.append(id)
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.verificationTimeout) {
      [weak self, weak connection] in
      MainActor.assumeIsolated {
        guard let self, let connection, self.pending.contains(id) else { return }
        self.finish(connection)
      }
    }
  }

  // the connection sent a valid CONNECT, so the verification deadline no longer applies.
  func markVerified(_ connection: NWConnection) {
    pending.removeAll { $0 == ObjectIdentifier(connection) }
  }

  func finish(_ connection: NWConnection) {
    let id = ObjectIdentifier(connection)
    connection.cancel()
    connections.removeValue(forKey: id)
    pending.removeAll { $0 == id }
  }

  func reply(_ connection: NWConnection, _ response: Data) {
    connection.send(
      content: response,
      completion: .contentProcessed { [weak self] _ in
        MainActor.assumeIsolated { self?.finish(connection) }
      })
  }

  // frees a slot by closing the oldest pending connection when all are taken, so idle
  // connections cannot lock the tunnel out. false when no slot can be freed.
  func makeRoom() -> Bool {
    guard connections.count >= Self.maximumConnections else { return true }
    guard let oldest = pending.first, let connection = connections[oldest] else {
      return false
    }
    finish(connection)
    return true
  }
}
