import Foundation

nonisolated struct PausedClone: Codable, Equatable, Sendable {
  let source: String
  let name: String
  let temporaryDirectoryName: String
  var hasPartialDownload: Bool
  let fraction: Double?
  let compressedDiskBytes: Int64?
  let pausedAt: Date

  var request: TartCloneRequest {
    TartCloneRequest(source: source, name: name)
  }
}
