import Darwin
import Foundation

actor ConnectionsRepository {
  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func load() throws -> [RunnerConnection] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return []
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular else {
      throw ConnectionsRepositoryError.invalidFileType
    }
    guard let permissions = attributes[.posixPermissions] as? NSNumber,
      permissions.intValue & 0o077 == 0
    else {
      throw ConnectionsRepositoryError.insecurePermissions
    }
    guard let size = attributes[.size] as? NSNumber,
      size.intValue <= 1_048_576
    else {
      throw ConnectionsRepositoryError.fileTooLarge
    }
    let data = try Data(contentsOf: fileURL)
    return try JSONDecoder().decode(ConnectionsDocument.self, from: data).connections
  }

  func save(_ connections: [RunnerConnection]) throws {
    let document = try ConnectionsDocument.validated(connections: connections)
    let parent = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: parent,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(document)
    data.append(0x0A)
    let temporaryURL = parent.appending(path: ".connections.\(UUID().uuidString).tmp")
    guard
      FileManager.default.createFile(
        atPath: temporaryURL.path,
        contents: data,
        attributes: [.posixPermissions: 0o600]
      )
    else {
      throw CocoaError(.fileWriteUnknown)
    }
    defer { try? FileManager.default.removeItem(at: temporaryURL) }
    let result = temporaryURL.path.withCString { source in
      fileURL.path.withCString { destination in
        Darwin.rename(source, destination)
      }
    }
    guard result == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
  }
}
