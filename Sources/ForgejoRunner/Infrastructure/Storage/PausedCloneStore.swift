import Foundation

// tart removes every unlocked directory in its tmp folder before most commands, so a
// paused partial download is moved into app owned state and moved back before resuming.
nonisolated struct PausedCloneStore: Sendable {
  let fileURL: URL
  let partialDirectory: URL
  let tartTemporaryDirectory: URL

  func load() throws -> PausedClone? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    let data = try Data(contentsOf: fileURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var clone = try decoder.decode(PausedClone.self, from: data)
    if clone.hasPartialDownload, !Self.containsDiskImage(partialDirectory) {
      clone.hasPartialDownload = false
    }
    return clone
  }

  func hasPartialDownload(for request: TartCloneRequest) -> Bool {
    locatePartialDownload(for: request) != nil
  }

  // moves the partial download out of tart's tmp folder and records the paused clone.
  func keep(_ request: TartCloneRequest, progress: TartCloneProgress) throws -> PausedClone {
    let located = locatePartialDownload(for: request)
    if let located {
      if FileManager.default.fileExists(atPath: partialDirectory.path) {
        try FileManager.default.removeItem(at: partialDirectory)
      }
      try FileManager.default.createDirectory(
        at: partialDirectory.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
      try FileManager.default.moveItem(at: located, to: partialDirectory)
    }
    let clone = PausedClone(
      source: request.source,
      name: request.name,
      temporaryDirectoryName: located?.lastPathComponent
        ?? request.remoteName?.temporaryDirectoryName ?? "",
      hasPartialDownload: located != nil,
      fraction: progress.fraction,
      compressedDiskBytes: progress.compressedDiskBytes,
      // whole seconds survive the iso8601 round trip unchanged.
      pausedAt: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
    )
    try save(clone)
    return clone
  }

  // moves the partial download back so tart resumes instead of starting over.
  func restore(_ clone: PausedClone) throws {
    guard clone.hasPartialDownload, Self.containsDiskImage(partialDirectory) else { return }
    guard !clone.temporaryDirectoryName.isEmpty else {
      throw PausedCloneStoreError.unknownTemporaryDirectory
    }
    let destination = tartTemporaryDirectory.appending(
      path: clone.temporaryDirectoryName,
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
      at: tartTemporaryDirectory,
      withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: partialDirectory, to: destination)
  }

  func discard() throws {
    if FileManager.default.fileExists(atPath: partialDirectory.path) {
      try FileManager.default.removeItem(at: partialDirectory)
    }
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
  }

  func removePartialDownload(for request: TartCloneRequest) {
    guard let located = locatePartialDownload(for: request) else { return }
    try? FileManager.default.removeItem(at: located)
  }

  private func locatePartialDownload(for request: TartCloneRequest) -> URL? {
    guard let remoteName = request.remoteName else { return nil }
    let expected = tartTemporaryDirectory.appending(
      path: remoteName.temporaryDirectoryName,
      directoryHint: .isDirectory
    )
    if Self.containsDiskImage(expected) {
      return expected
    }
    // fall back to the newest resumable pull directory if tart named it differently.
    guard
      let entries = try? FileManager.default.contentsOfDirectory(
        at: tartTemporaryDirectory,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return nil
    }
    return
      entries
      .filter { Self.isDeterministicName($0.lastPathComponent) && Self.containsDiskImage($0) }
      .max { Self.modificationDate($0) < Self.modificationDate($1) }
  }

  private func save(_ clone: PausedClone) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    var data = try encoder.encode(clone)
    data.append(0x0A)
    try data.write(to: fileURL, options: .atomic)
  }

  private static func containsDiskImage(_ directory: URL) -> Bool {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return false
    }
    return FileManager.default.fileExists(atPath: directory.appending(path: "disk.img").path)
  }

  private static func isDeterministicName(_ name: String) -> Bool {
    name.range(of: #"^[0-9a-f]{32}$"#, options: .regularExpression) != nil
  }

  private static func modificationDate(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
      ?? .distantPast
  }
}
