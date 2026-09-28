import Foundation

nonisolated struct ConnectionsDocument: Codable, Equatable, Sendable {
  let connections: [RunnerConnection]

  init(connections: [RunnerConnection]) {
    self.connections = connections.sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  static func validated(connections: [RunnerConnection]) throws -> ConnectionsDocument {
    guard connections.count <= 128 else {
      throw ConnectionValidationError.tooManyConnections
    }
    guard Set(connections.map(\.name)).count == connections.count else {
      throw ConnectionValidationError.duplicateName
    }
    guard Set(connections.map(\.uuid)).count == connections.count else {
      throw ConnectionValidationError.duplicateUUID
    }
    return ConnectionsDocument(connections: connections)
  }

  private enum CodingKeys: String, CodingKey {
    case server
  }

  init(from decoder: Decoder) throws {
    let container = try strictContainer(decoder, expectedKeys: ["server"])
    let server = try container.decode(Server.self, forKey: DynamicCodingKey("server"))
    let decoded = try server.connections.map { name, payload in
      try RunnerConnection.validated(
        name: name,
        url: payload.url,
        uuid: payload.uuid,
        token: payload.token,
        labels: payload.labels
      )
    }
    do {
      self = try ConnectionsDocument.validated(connections: decoded)
    } catch {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: error.localizedDescription)
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    let payloads = Dictionary(
      uniqueKeysWithValues: connections.map { connection in
        (
          connection.name,
          Payload(
            url: connection.url.absoluteString,
            uuid: connection.uuid.uuidString.lowercased(),
            token: connection.token.rawValue,
            labels: connection.labels
          )
        )
      })
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Server(connections: payloads), forKey: .server)
  }
}
