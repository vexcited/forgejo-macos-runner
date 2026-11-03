import Foundation

nonisolated struct RegistryManifest: Equatable, Sendable {
  let digest: String
  let uploadedAt: Date?
  let unpackedBytes: Int64
}
