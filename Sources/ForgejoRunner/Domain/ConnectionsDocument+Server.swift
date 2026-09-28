import Foundation

extension ConnectionsDocument {
  nonisolated struct Server: Codable {
    let connections: [String: Payload]

    init(connections: [String: Payload]) {
      self.connections = connections
    }

    init(from decoder: Decoder) throws {
      let container = try strictContainer(decoder, expectedKeys: ["connections"])
      connections = try container.decode(
        [String: Payload].self,
        forKey: DynamicCodingKey("connections")
      )
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: DynamicCodingKey.self)
      try container.encode(connections, forKey: DynamicCodingKey("connections"))
    }
  }
}
