import Foundation

// smooth numbers for the display, moved forward from the last sample at the measured speed.
extension TartCloneProgress {
  func shownBytes(at date: Date) -> Int64? {
    guard phase == .pullingDisk, let total = compressedDiskBytes else { return nil }
    let measured = max(downloadedBytes ?? 0, rate?.estimatedBytes(at: date) ?? 0)
    return min(measured, Int64(Double(total) * 0.99))
  }

  func shownFraction(at date: Date) -> Double? {
    if phase == .pullingNVRAM { return 1 }
    guard let bytes = shownBytes(at: date), let total = compressedDiskBytes, total > 0 else {
      return fraction
    }
    return Double(bytes) / Double(total)
  }

  func remainingTime(at date: Date) -> Duration? {
    guard let rate, rate.bytesPerSecond > 0, let total = compressedDiskBytes,
      let bytes = shownBytes(at: date)
    else { return nil }
    return .seconds(Double(total - bytes) / rate.bytesPerSecond)
  }
}
