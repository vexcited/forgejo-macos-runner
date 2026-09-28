import Foundation

nonisolated struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(_ stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(stringValue: String) {
    self.init(stringValue)
  }

  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }
}

nonisolated func strictContainer(
  _ decoder: Decoder,
  expectedKeys: Set<String>
) throws -> KeyedDecodingContainer<DynamicCodingKey> {
  let container = try decoder.container(keyedBy: DynamicCodingKey.self)
  let actualKeys = Set(container.allKeys.map(\.stringValue))
  guard actualKeys == expectedKeys else {
    let unexpected = actualKeys.subtracting(expectedKeys).sorted()
    let missing = expectedKeys.subtracting(actualKeys).sorted()
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: decoder.codingPath,
        debugDescription: "Unexpected keys: \(unexpected). Missing keys: \(missing)."
      )
    )
  }
  return container
}
