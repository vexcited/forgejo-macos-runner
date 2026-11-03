import Foundation

nonisolated struct RegistryTagList: Decodable, Sendable {
  let tags: [String]?
}
