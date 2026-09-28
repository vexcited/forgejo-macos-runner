import Foundation

enum AuthorizedKeysStep {
  static func replace(with sshPublicKey: String, home: String) throws {
    Console.log("replacing authorized ssh keys with the controller public key.")
    let sshDir = home + "/.ssh"
    try FileManager.default.createDirectory(
      atPath: sshDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let authorizedKeys = sshDir + "/authorized_keys"
    try Data((sshPublicKey + "\n").utf8).write(to: URL(filePath: authorizedKeys), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authorizedKeys)
  }
}
