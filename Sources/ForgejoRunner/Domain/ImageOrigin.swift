import Foundation

// where a local image was downloaded from, since tart does not remember it.
nonisolated struct ImageOrigin: Codable, Equatable, Sendable {
  let repository: String
  let tag: String
  // the version the tag pointed at, such as 27.2 for latest.
  let version: String?
  let digest: String
  let uploadedAt: Date?
}
