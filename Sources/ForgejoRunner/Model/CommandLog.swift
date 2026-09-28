import Foundation
import Observation

// Records every command the app runs, in memory for the UI and appended to a
// per-launch file under the app's Logs directory. `CommandRequest.loggableCommandLine`
// and `.description` already keep secrets out (stdin redacted, env values dropped),
// so entries are safe to persist.
@MainActor
@Observable
final class CommandLog {
  private(set) var entries: [CommandLogEntry] = []
  private let maxEntries = 2_000
  private let fileURL: URL?
  private var fileHandle: FileHandle?

  init(directory: URL?) {
    if let directory {
      let stamp = Self.timestamp(Date()).replacingOccurrences(of: ":", with: "-")
      fileURL = directory.appending(path: "commands-\(stamp).log", directoryHint: .notDirectory)
    } else {
      fileURL = nil
    }
  }

  func willRun(_ request: CommandRequest) {
    append("$ \(request.loggableCommandLine)")
  }

  func didFinish(executable: String, status: Int32, duration: Duration) {
    let seconds =
      Double(duration.components.seconds)
      + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    let outcome = status == 0 ? "ok" : "exit \(status)"
    append(String(format: "  -> %@ %@ (%.1fs)", executable, outcome, seconds))
  }

  func clear() {
    entries.removeAll()
  }

  private func append(_ text: String) {
    let entry = CommandLogEntry(id: UUID(), date: Date(), line: String(text.suffix(8_000)))
    entries.append(entry)
    if entries.count > maxEntries {
      entries.removeFirst(entries.count - maxEntries)
    }
    persist(entry)
  }

  private func persist(_ entry: CommandLogEntry) {
    guard let fileURL else { return }
    if fileHandle == nil {
      // the Logs directory is created by AppPaths.prepare(); retry until it exists.
      guard
        FileManager.default.createFile(
          atPath: fileURL.path,
          contents: nil,
          attributes: [.posixPermissions: 0o600]
        ),
        let handle = try? FileHandle(forWritingTo: fileURL)
      else {
        return
      }
      _ = try? handle.seekToEnd()
      fileHandle = handle
    }
    guard let data = "\(Self.timestamp(entry.date)) \(entry.line)\n".data(using: .utf8) else {
      return
    }
    try? fileHandle?.write(contentsOf: data)
  }

  private static func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }
}
