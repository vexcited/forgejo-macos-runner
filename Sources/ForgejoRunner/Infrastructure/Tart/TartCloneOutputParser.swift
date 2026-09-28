import Foundation

// turns the line oriented output of tart clone into progress state.
nonisolated struct TartCloneOutputParser: Sendable {
  private(set) var progress = TartCloneProgress()
  private var pendingLine = ""

  // consumes a raw output chunk and returns it without terminal control sequences.
  mutating func consume(_ chunk: String) -> String {
    let cleaned = Self.removingControlSequences(chunk)
    var text = pendingLine + cleaned
    while let newline = text.firstIndex(of: "\n") {
      apply(String(text[..<newline]))
      text = String(text[text.index(after: newline)...])
    }
    pendingLine = String(text.suffix(4_096))
    return cleaned
  }

  static func removingControlSequences(_ text: String) -> String {
    text
      .replacingOccurrences(
        of: #"\x1B\[[0-9;?]*[ -/]*[@-~]"#,
        with: "",
        options: .regularExpression
      )
      .replacingOccurrences(of: "\r", with: "")
  }

  private mutating func apply(_ rawLine: String) {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    guard !line.isEmpty else { return }
    if let percent = Self.percent(in: line) {
      progress.fraction = Double(min(max(percent, 0), 100)) / 100
      if progress.phase != .pullingNVRAM {
        progress.phase = .pullingDisk
      }
      return
    }
    if line.hasPrefix("pulling manifest") {
      progress.phase = .pullingManifest
      return
    }
    if line.hasPrefix("pulling disk") {
      progress.phase = .pullingDisk
      progress.fraction = 0
      progress.compressedDiskBytes = Self.compressedDiskBytes(in: line)
      return
    }
    if line.hasPrefix("pulling NVRAM") {
      progress.phase = .pullingNVRAM
      progress.fraction = 1
      return
    }
    progress.statusLine = String(line.prefix(300))
  }

  private static func percent(in line: String) -> Int? {
    guard line.hasSuffix("%") else { return nil }
    return Int(line.dropLast())
  }

  private static func compressedDiskBytes(in line: String) -> Int64? {
    guard
      let range = line.range(
        of: #"\(([0-9]+(?:\.[0-9]+)?) GB compressed\)"#,
        options: .regularExpression
      )
    else {
      return nil
    }
    let numberText = line[range]
      .dropFirst()
      .prefix { $0.isNumber || $0 == "." }
    guard let gigabytes = Double(numberText) else { return nil }
    return Int64((gigabytes * 1_000_000_000).rounded())
  }
}
