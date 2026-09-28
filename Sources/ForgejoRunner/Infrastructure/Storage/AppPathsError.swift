import Foundation

nonisolated enum AppPathsError: LocalizedError, Equatable, Sendable {
  case migrationConflict
  case invalidLegacyStorage

  var errorDescription: String? {
    switch self {
    case .migrationConflict:
      "Both the old and new Forgejo storage locations contain data. Resolve them manually before opening the app."
    case .invalidLegacyStorage:
      "The legacy Forgejo application support location is not a directory."
    }
  }
}
