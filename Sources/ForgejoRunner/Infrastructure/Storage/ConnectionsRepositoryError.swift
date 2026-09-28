import Foundation

nonisolated enum ConnectionsRepositoryError: LocalizedError, Sendable {
  case invalidFileType
  case insecurePermissions
  case fileTooLarge

  var errorDescription: String? {
    switch self {
    case .invalidFileType:
      "The connections manifest must be a regular file."
    case .insecurePermissions:
      "The connections manifest must not be accessible by group or other users."
    case .fileTooLarge:
      "The connections manifest must not exceed 1 MiB."
    }
  }
}
