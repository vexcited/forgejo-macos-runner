import Foundation

nonisolated struct TartCloneProgress: Equatable, Sendable {
  var phase: TartClonePhase = .starting
  var fraction: Double?
  var compressedDiskBytes: Int64?
  var statusLine: String?
  var rate: DownloadRate?

  var downloadedBytes: Int64? {
    guard let fraction, let compressedDiskBytes else { return nil }
    return Int64((Double(compressedDiskBytes) * fraction).rounded())
  }

  // appended to activity messages, for example " at 42%".
  var percentSuffix: String {
    guard let fraction else { return "" }
    return " at \(Int((fraction * 100).rounded()))%"
  }
}
