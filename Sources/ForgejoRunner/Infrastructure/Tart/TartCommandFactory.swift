import Foundation

nonisolated struct TartCommandFactory: Sendable {
  let executableURL: URL
  let tartHome: URL
  let baseEnvironment: [String: String]

  var environment: [String: String] {
    var values = baseEnvironment
    values["TART_HOME"] = tartHome.path
    return values
  }

  // the syntax of each tart command that these requests rely on.
  static let requiredSyntax: [(String, [String])] = [
    ("list", ["--source", "--format"]),
    ("clone", ["<source-name>", "<new-name>"]),
    (
      "run",
      [
        "--no-graphics", "--no-audio", "--no-clipboard", "--net-softnet", "--net-softnet-allow",
        "--net-softnet-block",
      ]
    ),
    ("ip", ["--wait"]),
    ("stop", ["--timeout"]),
    ("prune", ["--entries", "--space-budget"]),
    ("delete", ["<name>"]),
    ("exec", ["-i"]),
  ]

  func version() -> CommandRequest {
    request(["--version"])
  }

  func help(for command: String) -> CommandRequest {
    request([command, "--help"])
  }

  func list() -> CommandRequest {
    request(["list", "--source", "local", "--format", "json"])
  }

  func clone(source: String, name: String) -> CommandRequest {
    var values = environment
    values["TART_NO_AUTO_PRUNE"] = "1"
    // tart prints plain percent lines instead of cursor movement sequences when CI is set.
    values["CI"] = "1"
    return CommandRequest(
      executableURL: executableURL,
      arguments: ["clone", source, name],
      environment: values
    )
  }

  func run(name: String, networkMode: TartNetworkMode) -> CommandRequest {
    var arguments = ["run", "--no-graphics", "--no-audio", "--no-clipboard"]
    switch networkMode {
    case .provisioning:
      arguments += ["--net-softnet", "--net-softnet-block=in 0.0.0.0/0,224.0.0.0/4"]
    case .sandboxed(let blockedNetworks):
      // the stateful rules refuse every connection the vm opens to this mac, including
      // through the public networks it sits on and its public egress address, and
      // every connection into the vm except the app's own ssh from this mac. multicast
      // never leaves the vm. replies to the vm's internet traffic still pass as tracked
      // flows.
      let blocks =
        ["out @host", "in 0.0.0.0/0", "224.0.0.0/4"] + blockedNetworks.sorted().map { "out \($0)" }
      arguments += [
        "--net-softnet",
        "--net-softnet-allow=in @host",
        "--net-softnet-block=\(blocks.joined(separator: ","))",
      ]
    }
    arguments.append(name)
    return inVMDirectory(request(arguments), name: name)
  }

  func ip(name: String, timeout: Int) -> CommandRequest {
    request(["ip", name, "--wait", String(timeout)])
  }

  func stop(name: String, timeout: Int) -> CommandRequest {
    request(["stop", name, "--timeout", String(timeout)])
  }

  func delete(name: String) -> CommandRequest {
    request(["delete", name])
  }

  func pruneCaches() -> CommandRequest {
    request(["prune", "--entries", "caches", "--space-budget", "0"])
  }

  func execute(name: String, arguments: [String], standardInput: Data? = nil) -> CommandRequest {
    var command = request(["exec"] + (standardInput == nil ? [] : ["-i"]) + [name] + arguments)
    command.standardInput = standardInput
    return inVMDirectory(command, name: name)
  }

  // tart run and tart exec meet on a control socket they both open by a path relative to
  // the vm folder. tart moves into that folder with a percent encoded path, which fails
  // under "Application Support", so both start there already or never find each other.
  private func inVMDirectory(_ request: CommandRequest, name: String) -> CommandRequest {
    var request = request
    request.workingDirectory = vmDirectory(for: name)
    return request
  }

  func controlSocket(for name: String) -> URL {
    vmDirectory(for: name).appending(path: "control.sock", directoryHint: .notDirectory)
  }

  private func vmDirectory(for name: String) -> URL {
    tartHome.appending(path: "vms", directoryHint: .isDirectory)
      .appending(path: name, directoryHint: .isDirectory)
  }

  private func request(_ arguments: [String]) -> CommandRequest {
    CommandRequest(
      executableURL: executableURL,
      arguments: arguments,
      environment: environment
    )
  }
}
