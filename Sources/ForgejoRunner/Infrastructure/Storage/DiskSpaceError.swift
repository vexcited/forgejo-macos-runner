import Foundation

nonisolated enum DiskSpaceError: LocalizedError, Sendable {
  case notEnough(needed: Int64, available: Int64)
  case reservationFailed(Int32)

  var errorDescription: String? {
    switch self {
    case .notEnough(let needed, let available):
      "Not enough disk space. This image needs \(Self.format(needed)) free and \(Self.format(available)) is available."
    case .reservationFailed(let code):
      "Could not set aside disk space: \(String(cString: strerror(code)))."
    }
  }

  private static func format(_ bytes: Int64) -> String {
    bytes.formatted(.byteCount(style: .file))
  }
}
