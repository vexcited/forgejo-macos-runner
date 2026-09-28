import Foundation

// turns periodic byte counts into a steady speed with a moving average.
nonisolated struct DownloadRateTracker: Sendable {
  private(set) var rate: DownloadRate?
  private var last: (bytes: Int64, date: Date)?

  mutating func record(_ bytes: Int64, at date: Date) {
    defer { last = (bytes, date) }
    guard let last, date > last.date, bytes >= last.bytes else { return }
    let interval = date.timeIntervalSince(last.date)
    let instant = Double(bytes - last.bytes) / interval
    let speed = rate.map { $0.bytesPerSecond * 0.7 + instant * 0.3 } ?? instant
    // aims a little short of the next sample, so the display rarely runs ahead.
    let target = Double(bytes) + speed * 0.9 * interval
    let start = max(bytes, rate?.estimatedBytes(at: date) ?? bytes)
    rate = DownloadRate(
      bytes: start,
      sampledAt: date,
      displaySpeed: max(0, (target - Double(start)) / interval),
      interval: interval,
      bytesPerSecond: speed
    )
  }
}
