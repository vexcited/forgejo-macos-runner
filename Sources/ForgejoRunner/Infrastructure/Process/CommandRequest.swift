import Foundation

nonisolated struct CommandRequest: Equatable, Sendable, CustomStringConvertible {
  let executableURL: URL
  let arguments: [String]
  let environment: [String: String]
  var standardInput: Data?
  var outputLimitBytes: Int
  var terminationGracePeriod: Duration?
  // frequent polling commands stay out of the command log.
  var isLogged: Bool
  var workingDirectory: URL?

  init(
    executableURL: URL,
    arguments: [String],
    environment: [String: String] = [:],
    standardInput: Data? = nil,
    outputLimitBytes: Int = 1_048_576,
    terminationGracePeriod: Duration? = nil,
    isLogged: Bool = true
  ) {
    self.executableURL = executableURL
    self.arguments = arguments
    self.environment = environment
    self.standardInput = standardInput
    self.outputLimitBytes = max(1, outputLimitBytes)
    self.terminationGracePeriod = terminationGracePeriod
    self.isLogged = isLogged
  }

  var description: String {
    "CommandRequest(executableURL: \(executableURL.path), arguments: \(arguments), environmentKeys: \(environment.keys.sorted()), standardInput: \(standardInput == nil ? "none" : "<redacted>"))"
  }

  // a readable, shell-like command line for logging. arguments never carry
  // secrets (tokens travel via standard input, passwords via SSH_ASKPASS files),
  // and standard input is redacted, so this is safe to record.
  var loggableCommandLine: String {
    let renderedArguments = arguments.map { argument in
      argument.isEmpty
        || argument.contains(where: { $0 == " " || $0 == "\t" || $0 == "\"" })
        ? "\"\(argument.replacingOccurrences(of: "\"", with: "\\\""))\""
        : argument
    }.joined(separator: " ")
    let stdin = standardInput == nil ? "" : " < <stdin redacted>"
    return "\(executableURL.path) \(renderedArguments)\(stdin)"
  }
}
