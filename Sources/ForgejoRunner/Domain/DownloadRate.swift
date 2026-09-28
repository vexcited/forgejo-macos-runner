import Foundation

// what the display shows between samples: it starts where the screen already is and
// moves toward where the next sample should land, so it never jumps backwards.
nonisolated struct DownloadRate: Equatable, Sendable {
  let bytes: Int64
  let sampledAt: Date
  // the speed the display moves at until the next sample.
  let displaySpeed: Double
  let interval: TimeInterval
  // the measured speed, for the time left.
  let bytesPerSecond: Double

  func estimatedBytes(at date: Date) -> Int64 {
    let elapsed = min(max(date.timeIntervalSince(sampledAt), 0), interval)
    return bytes + Int64(displaySpeed * elapsed)
  }
}
