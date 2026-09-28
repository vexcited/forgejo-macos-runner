import Foundation

// merges tart's own output with the measured network bytes into one progress value.
nonisolated struct CloneProgressTracker: Sendable {
  private var parser = TartCloneOutputParser()
  private var receivedBytes: Int64?
  private var rateTracker = DownloadRateTracker()

  // tart's own view, kept with a paused download.
  var reported: TartCloneProgress { parser.progress }

  // tart's own percent wins once it is ahead, and the estimate never claims the end.
  var progress: TartCloneProgress {
    var progress = parser.progress
    if progress.phase == .pullingDisk, let receivedBytes, let total = progress.compressedDiskBytes,
      total > 0
    {
      let estimate = min(Double(receivedBytes) / Double(total), 0.99)
      progress.fraction = max(progress.fraction ?? 0, estimate)
      progress.rate = rateTracker.rate
    }
    return progress
  }

  // returns the output without terminal control sequences.
  mutating func consume(_ output: String) -> String {
    parser.consume(output)
  }

  mutating func record(receivedBytes bytes: Int64, at date: Date) {
    receivedBytes = bytes
    rateTracker.record(bytes, at: date)
  }
}
