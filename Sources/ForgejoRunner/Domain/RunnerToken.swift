import Foundation

// the runner token, stored inline in the private connections.json.
nonisolated struct RunnerToken: Codable, Hashable, Sendable, CustomStringConvertible {
  let rawValue: String

  var description: String {
    "<redacted>"
  }
}
