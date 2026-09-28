import Foundation

nonisolated struct CommandFailure: LocalizedError, Sendable {
  let executable: String
  let status: Int32
  let output: String

  var errorDescription: String? {
    let summary = output.trimmingCharacters(in: .whitespacesAndNewlines)
    let boundedSummary = String(summary.suffix(4_000))
    return summary.isEmpty
      ? "\(executable) exited with status \(status)."
      : "\(executable) exited with status \(status): \(boundedSummary)"
  }
}
