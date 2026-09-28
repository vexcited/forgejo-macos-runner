import Foundation

nonisolated struct SSHCommandFactory: Sendable {
  // every session pins its own fresh host key under this name, see trustSessionHostKey.
  static let sessionHostAlias = "forgejo-runner-session"

  let executableURL: URL
  let identityFile: URL
  let knownHostsFile: URL
  let user: String
  let baseEnvironment: [String: String]

  func version() -> CommandRequest {
    CommandRequest(
      executableURL: executableURL,
      arguments: ["-V"],
      environment: baseEnvironment
    )
  }

  func readiness(ipAddress: String) -> CommandRequest {
    command(ipAddress: ipAddress, remoteCommand: "true", detachedInput: true)
  }

  func validateGuest(ipAddress: String) -> CommandRequest {
    command(
      ipAddress: ipAddress,
      remoteCommand: "/usr/local/libexec/forgejo-one-job --validate",
      detachedInput: true
    )
  }

  // the guest runner reaches the broker through a reverse forward on this pinned
  // connection, from guestPort on the guest loopback to the broker's private socket.
  func runOneJob(
    ipAddress: String,
    connection: RunnerConnection,
    proxyURL: String,
    brokerForward: BrokerForward
  ) -> CommandRequest {
    return command(
      ipAddress: ipAddress,
      remoteCommand: "/usr/local/libexec/forgejo-one-job",
      detachedInput: false,
      standardInput: RunnerConnectionStream.encode(connection: connection, proxyURL: proxyURL),
      brokerForward: brokerForward
    )
  }

  private func command(
    ipAddress: String,
    remoteCommand: String,
    detachedInput: Bool,
    standardInput: Data? = nil,
    brokerForward: BrokerForward? = nil
  ) -> CommandRequest {
    var arguments = [
      "-F", "/dev/null",
      "-o", "BatchMode=yes",
      "-o", "IdentitiesOnly=yes",
      "-o", "StrictHostKeyChecking=yes",
      // inner-quote the path: ssh splits UserKnownHostsFile on whitespace, and the
      // app data dir contains a space ("Application Support").
      "-o", "UserKnownHostsFile=\"\(knownHostsFile.path)\"",
      "-o", "GlobalKnownHostsFile=/dev/null",
      "-o", "HostKeyAlias=\(Self.sessionHostAlias)",
      "-o", "HostKeyAlgorithms=ssh-ed25519",
      "-o", "UpdateHostKeys=no",
      "-o", "CheckHostIP=no",
      "-o", "ForwardAgent=no",
      "-o", "ForwardX11=no",
      "-o", "PasswordAuthentication=no",
      "-o", "KbdInteractiveAuthentication=no",
      "-o", "PermitLocalCommand=no",
      "-o", "RequestTTY=no",
      "-o", "LogLevel=ERROR",
      "-o", "ConnectTimeout=5",
      "-o", "ServerAliveInterval=15",
      "-o", "ServerAliveCountMax=4",
      "-i", identityFile.path,
    ]
    if let brokerForward {
      // -F /dev/null leaves this reverse forward as the only one.
      arguments += [
        "-o", "ExitOnForwardFailure=yes",
        "-R", "127.0.0.1:\(brokerForward.guestPort):\(brokerForward.hostSocket)",
      ]
    } else {
      arguments += ["-o", "ClearAllForwardings=yes"]
    }
    if detachedInput {
      arguments.append("-n")
    }
    arguments.append("\(user)@\(ipAddress)")
    arguments.append(remoteCommand)
    return CommandRequest(
      executableURL: executableURL,
      arguments: arguments,
      environment: baseEnvironment,
      standardInput: standardInput,
      outputLimitBytes: detachedInput ? 65_536 : 262_144
    )
  }

}
