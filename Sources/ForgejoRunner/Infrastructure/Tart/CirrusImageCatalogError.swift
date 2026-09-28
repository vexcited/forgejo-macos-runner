import Foundation

nonisolated enum CirrusImageCatalogError: LocalizedError, Sendable {
  case unexpectedStatus(Int)
  case noImages

  var errorDescription: String? {
    switch self {
    case .unexpectedStatus(let status):
      "GitHub answered with HTTP status \(status)."
    case .noImages:
      "GitHub returned no Cirrus Labs images."
    }
  }
}
