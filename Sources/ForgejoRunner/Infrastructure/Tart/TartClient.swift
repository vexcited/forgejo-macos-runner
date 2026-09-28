import Foundation

@MainActor
final class TartClient {
  private let commands: CommandExecuting
  private(set) var factory: TartCommandFactory

  init(commands: CommandExecuting, factory: TartCommandFactory) {
    self.commands = commands
    self.factory = factory
  }

  private var sandbox: SoftnetSandbox {
    SoftnetSandbox(commands: commands, environment: factory.environment)
  }

  func configure(factory: TartCommandFactory) {
    self.factory = factory
  }

  func validateCLI() async throws -> String {
    guard FileManager.default.isExecutableFile(atPath: factory.executableURL.path) else {
      throw TartError.notExecutable(factory.executableURL.path)
    }
    let version = try await commands.checked(factory.version(), timeout: .seconds(10)).outputString
      .trimmingCharacters(in: .whitespacesAndNewlines)
    for (command, flags) in TartCommandFactory.requiredSyntax {
      let help = try await commands.checked(factory.help(for: command), timeout: .seconds(10))
        .outputString
      for flag in flags where !help.contains(flag) {
        throw TartError.missingSyntax(command: command, value: flag)
      }
    }
    return version
  }

  func images() async throws -> [TartImage] {
    let result = try await commands.checked(factory.list(), timeout: .seconds(30))
    return try TartImage.decodeList(result.output)
  }

  func clone(
    source: String,
    name: String,
    timeout: Duration = .seconds(21_600),
    outputHandler: (@MainActor @Sendable (String) -> Void)? = nil
  ) async throws {
    try TartInputValidation.validateName(name)
    let normalizedSource = try TartInputValidation.normalizedSource(source)
    _ = try await commands.checked(
      factory.clone(source: normalizedSource, name: name),
      timeout: timeout,
      outputHandler: outputHandler
    )
    // tart keeps every download in its cache as well. the cloned vm is complete on its
    // own, so the cache is emptied. a leftover cache only takes space, so a failure here
    // does not fail the clone.
    if normalizedSource.contains("/") {
      _ = try? await commands.checked(factory.pruneCaches(), timeout: .seconds(300))
    }
  }

  func clone(
    source: String,
    name: String,
    outputHandler: (@MainActor @Sendable (String) -> Void)?
  ) async throws {
    try await clone(
      source: source,
      name: name,
      timeout: .seconds(21_600),
      outputHandler: outputHandler
    )
  }

  func runVM(
    name: String,
    networkMode: TartNetworkMode,
    outputHandler: (@MainActor @Sendable (String) -> Void)? = nil
  ) async throws -> CommandResult {
    try TartInputValidation.validateName(name)
    // tart deletes the socket of the previous boot with a percent encoded path, which
    // fails under "Application Support", and then cannot listen on the leftover file.
    try? FileManager.default.removeItem(at: factory.controlSocket(for: name))
    return try await commands.checked(
      factory.run(name: name, networkMode: networkMode),
      timeout: nil,
      outputHandler: outputHandler
    )
  }

  func waitForIPAddress(name: String, timeoutSeconds: Int) async throws -> String {
    try TartInputValidation.validateName(name)
    let result = try await commands.checked(
      factory.ip(name: name, timeout: timeoutSeconds),
      timeout: .seconds(timeoutSeconds + 10)
    )
    let address = result.outputString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !address.isEmpty,
      address.range(of: #"^[0-9A-Fa-f:.]+$"#, options: .regularExpression) != nil
    else {
      throw TartError.invalidIPAddress
    }
    return address
  }

  func stop(name: String, timeoutSeconds: Int) async throws {
    try TartInputValidation.validateName(name)
    _ = try await commands.checked(
      factory.stop(name: name, timeout: timeoutSeconds),
      timeout: .seconds(timeoutSeconds + 10)
    )
  }

  func delete(name: String) async throws {
    try TartInputValidation.validateName(name)
    _ = try await commands.checked(factory.delete(name: name), timeout: .seconds(60))
  }

  func execute(
    name: String,
    arguments: [String],
    standardInput: Data? = nil,
    timeout: Duration = .seconds(60),
    outputHandler: (@MainActor @Sendable (String) -> Void)? = nil
  ) async throws -> CommandResult {
    try TartInputValidation.validateName(name)
    return try await commands.checked(
      factory.execute(name: name, arguments: arguments, standardInput: standardInput),
      timeout: timeout,
      outputHandler: outputHandler
    )
  }

  func sandboxStatus() async -> SandboxStatus {
    await sandbox.status()
  }

  func grantSandboxPrivileges() async throws {
    try await sandbox.grantPrivileges()
  }

  func containsImage(named name: String) async throws -> Bool {
    try await images().contains(where: { $0.name == name })
  }
}
