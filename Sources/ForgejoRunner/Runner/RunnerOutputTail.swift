import Foundation

// keeps the end of the runner output so a failed session can show why it failed.
@MainActor
final class RunnerOutputTail {
  private var text = ""

  func reset() {
    text = ""
  }

  func append(_ output: String) {
    let combinedOutput = text + output
    text = String(combinedOutput.suffix(2_000))
  }

  // surfaces why a runner session failed. the guest wrote this text, so control
  // characters are removed, and any resolved token is redacted as a last guard.
  func logFailure(
    redacting connections: [ResolvedRunnerConnection],
    to logHandler: @MainActor @Sendable (String) -> Void
  ) {
    var tail = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !tail.isEmpty else { return }
    for resolved in connections where !resolved.token.isEmpty {
      tail = tail.replacingOccurrences(of: resolved.token, with: "<redacted>")
    }
    logHandler("Last runner output: \(LogText.printable(String(tail.suffix(1_000)), limit: 1_000))")
  }
}
