import Foundation

nonisolated enum ImageUpdateStatus: Equatable, Sendable {
  case upToDate
  case available(version: String?, uploadedAt: Date?)

  var isAvailable: Bool {
    if case .available = self { return true }
    return false
  }
}
