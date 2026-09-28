import Foundation
import Security

// a throwaway self-signed tls identity for the broker. the guest runner runs with
// runner.insecure because its only tls peer is the broker, so nothing needs to trust
// this certificate. it lives in memory and never touches a keychain.
@MainActor
enum BrokerIdentity {
  private static var cached: SecIdentity?

  static func shared(commands: CommandExecuting) async throws -> SecIdentity {
    if let cached { return cached }
    let identity = try await generate(commands: commands)
    cached = identity
    return identity
  }

  private static func generate(commands: CommandExecuting) async throws -> SecIdentity {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "forgejo-broker-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }

    let key = directory.appending(path: "key.pem").path
    let certificate = directory.appending(path: "certificate.pem").path
    let bundle = directory.appending(path: "identity.p12").path
    let password = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let openssl = URL(filePath: "/usr/bin/openssl")

    try await run(
      commands, openssl,
      [
        "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256", "-days", "30",
        "-subj", "/CN=Forgejo Runner broker", "-keyout", key, "-out", certificate,
      ])
    try await run(
      commands, openssl,
      [
        "pkcs12", "-export", "-inkey", key, "-in", certificate, "-out", bundle,
        "-certpbe", "PBE-SHA1-3DES", "-keypbe", "PBE-SHA1-3DES", "-macalg", "sha1",
        "-passout", "env:BROKER_P12_PASSWORD",
      ],
      environment: ["BROKER_P12_PASSWORD": password])

    let data = try Data(contentsOf: URL(filePath: bundle))
    var items: CFArray?
    let options: [String: Any] = [
      kSecImportExportPassphrase as String: password,
      kSecImportToMemoryOnly as String: true,
    ]
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
    guard status == errSecSuccess,
      let entries = items as? [[String: Any]],
      let entry = entries.first,
      let identity = entry[kSecImportItemIdentity as String]
    else {
      throw BrokerIdentityError.importFailed(status)
    }
    return identity as! SecIdentity
  }

  private static func run(
    _ commands: CommandExecuting,
    _ executable: URL,
    _ arguments: [String],
    environment: [String: String] = [:]
  ) async throws {
    let result = try await commands.run(
      CommandRequest(executableURL: executable, arguments: arguments, environment: environment),
      timeout: .seconds(30),
      outputHandler: nil
    )
    guard result.status == 0 else {
      throw BrokerIdentityError.generationFailed(result.outputString)
    }
  }
}
