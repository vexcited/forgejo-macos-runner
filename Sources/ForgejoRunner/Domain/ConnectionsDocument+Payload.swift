import Foundation

extension ConnectionsDocument {
  nonisolated struct Payload: Codable {
    let url: String
    let uuid: String
    let token: String
    let labels: [String]

    init(url: String, uuid: String, token: String, labels: [String]) {
      self.url = url
      self.uuid = uuid
      self.token = token
      self.labels = labels
    }

    init(from decoder: Decoder) throws {
      let container = try strictContainer(
        decoder,
        expectedKeys: ["url", "uuid", "token", "labels"]
      )
      url = try container.decode(String.self, forKey: DynamicCodingKey("url"))
      uuid = try container.decode(String.self, forKey: DynamicCodingKey("uuid"))
      token = try container.decode(String.self, forKey: DynamicCodingKey("token"))
      labels = try container.decode([String].self, forKey: DynamicCodingKey("labels"))
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: DynamicCodingKey.self)
      try container.encode(url, forKey: DynamicCodingKey("url"))
      try container.encode(uuid, forKey: DynamicCodingKey("uuid"))
      try container.encode(token, forKey: DynamicCodingKey("token"))
      try container.encode(labels, forKey: DynamicCodingKey("labels"))
    }
  }
}
