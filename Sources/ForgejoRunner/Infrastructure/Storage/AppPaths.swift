import Foundation

nonisolated struct AppPaths: Sendable {
  let homeDirectory: URL
  let applicationSupportDirectory: URL

  var appSupport: URL {
    applicationSupportDirectory.appending(
      path: "Forgejo",
      directoryHint: .isDirectory
    )
  }

  var connectionsFile: URL {
    appSupport.appending(
      path: "connections.json",
      directoryHint: .notDirectory
    )
  }

  var tartHome: URL {
    appSupport.appending(path: "Tart", directoryHint: .isDirectory)
  }

  var tartTemporaryDirectory: URL {
    tartHome.appending(path: "tmp", directoryHint: .isDirectory)
  }

  // holds free space for a download, next to the tart home so it is on the same volume.
  var downloadReservationFile: URL {
    appSupport.appending(path: "download-reservation", directoryHint: .notDirectory)
  }

  var logsDirectory: URL {
    appSupport.appending(path: "Logs", directoryHint: .isDirectory)
  }

  var stateDirectory: URL {
    appSupport.appending(path: "State", directoryHint: .isDirectory)
  }

  var sshDirectory: URL {
    appSupport.appending(path: "SSH", directoryHint: .isDirectory)
  }

  var secretsDirectory: URL {
    appSupport.appending(path: "Secrets", directoryHint: .isDirectory)
  }

  var pausedCloneFile: URL {
    stateDirectory.appending(path: "paused-clone.json", directoryHint: .notDirectory)
  }

  var pausedCloneDirectory: URL {
    stateDirectory.appending(path: "paused-clone", directoryHint: .isDirectory)
  }

  var sshIdentityFile: URL {
    sshDirectory.appending(path: "controller_ed25519")
  }

  // the host key of the current runner vm only, rewritten for every session.
  var sshSessionKnownHostsFile: URL {
    sshDirectory.appending(path: "session_known_hosts")
  }

  func prepare() throws {
    try LegacyStorageMigration(paths: self).run()
    for directory in [
      appSupport, tartHome, logsDirectory, stateDirectory, sshDirectory, secretsDirectory,
    ] {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: directory.path
      )
    }
  }

  static var live: AppPaths {
    let manager = FileManager.default
    let applicationSupport = manager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    return AppPaths(
      homeDirectory: manager.homeDirectoryForCurrentUser,
      applicationSupportDirectory: applicationSupport
    )
  }
}
