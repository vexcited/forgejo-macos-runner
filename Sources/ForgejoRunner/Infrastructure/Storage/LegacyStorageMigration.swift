import Foundation

// moves data from the storage locations of earlier versions into AppPaths.
nonisolated struct LegacyStorageMigration: Sendable {
  let paths: AppPaths

  private var legacyAppSupport: URL {
    paths.applicationSupportDirectory.appending(
      path: "ForgejoMacOSRunner",
      directoryHint: .isDirectory
    )
  }

  private var legacyConnectionsFile: URL {
    paths.homeDirectory.appending(
      path: ".config/forgejo/connections.json",
      directoryHint: .notDirectory
    )
  }

  func run() throws {
    let manager = FileManager.default
    let hasLegacySupport = manager.fileExists(atPath: legacyAppSupport.path)
    let hasCurrentSupport = manager.fileExists(atPath: paths.appSupport.path)
    let hasLegacyConnections = manager.fileExists(atPath: legacyConnectionsFile.path)
    let hasMigratedConnections =
      manager.fileExists(
        atPath: legacyAppSupport.appending(path: "connections.json").path
      )
      || manager.fileExists(atPath: paths.connectionsFile.path)

    if hasLegacySupport, hasCurrentSupport {
      throw AppPathsError.migrationConflict
    }
    if hasLegacyConnections, hasMigratedConnections {
      throw AppPathsError.migrationConflict
    }
    if hasLegacySupport {
      try requireDirectory(legacyAppSupport)
      try manager.createDirectory(
        at: paths.applicationSupportDirectory,
        withIntermediateDirectories: true
      )
      try manager.moveItem(at: legacyAppSupport, to: paths.appSupport)
    }
    if hasLegacyConnections {
      try manager.createDirectory(
        at: paths.appSupport,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
      try manager.moveItem(at: legacyConnectionsFile, to: paths.connectionsFile)
      try manager.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: paths.connectionsFile.path
      )
      try removeLegacyConnectionsDirectoryIfEmpty()
    }
  }

  private func requireDirectory(_ url: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard attributes[.type] as? FileAttributeType == .typeDirectory else {
      throw AppPathsError.invalidLegacyStorage
    }
  }

  private func removeLegacyConnectionsDirectoryIfEmpty() throws {
    let directory = legacyConnectionsFile.deletingLastPathComponent()
    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    if contents.isEmpty {
      try FileManager.default.removeItem(at: directory)
    }
  }
}
