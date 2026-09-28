import Foundation
import Observation

@MainActor
@Observable
final class ActivityLog {
  private(set) var entries: [ActivityEntry] = []

  func append(_ message: String) {
    entries.append(
      ActivityEntry(id: UUID(), date: Date(), message: String(message.suffix(4_000)))
    )
    if entries.count > 500 {
      entries.removeFirst(entries.count - 500)
    }
  }

  func clear() {
    entries.removeAll()
  }
}
