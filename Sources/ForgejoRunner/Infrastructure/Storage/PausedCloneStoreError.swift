import Foundation

nonisolated enum PausedCloneStoreError: LocalizedError, Sendable {
  case unknownTemporaryDirectory

  var errorDescription: String? {
    "The paused clone does not record where Tart expects its partial download."
  }
}
