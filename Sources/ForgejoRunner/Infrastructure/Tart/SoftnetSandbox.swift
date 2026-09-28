import Foundation

// checks and sets up the softnet that tart finds in PATH, which enforces the runner sandbox.
@MainActor
struct SoftnetSandbox {
  let commands: CommandExecuting
  let environment: [String: String]

  // whether softnet can enforce the runner sandbox. tart runs softnet as root through
  // passwordless sudo, which the setup limits to this user and this exact binary. a
  // setuid softnet would let every local user run it as root, so it is not accepted.
  func status() async -> SandboxStatus {
    guard let softnet = executable() else { return .missing }
    let help = try? await commands.run(
      CommandRequest(
        executableURL: softnet.resolved, arguments: ["--help"],
        environment: environment),
      timeout: .seconds(10), outputHandler: nil)
    // stateful rules such as "out @host" arrived in softnet 0.22.0.
    guard let help, help.status == 0, help.outputString.contains("out @host") else {
      return .outdated(softnet.resolved.path)
    }
    if let attributes = try? FileManager.default.attributesOfItem(
      atPath: softnet.resolved.path),
      (attributes[.ownerAccountID] as? NSNumber)?.intValue == 0,
      let permissions = attributes[.posixPermissions] as? NSNumber,
      permissions.intValue & Int(S_ISUID) != 0
    {
      return .needsPrivileges(softnet.resolved.path)
    }
    let sudo = try? await commands.run(
      CommandRequest(
        executableURL: URL(filePath: "/usr/bin/sudo"),
        arguments: ["--non-interactive", "softnet", "--help"], environment: environment),
      timeout: .seconds(10), outputHandler: nil)
    return sudo?.status == 0 ? .ready : .needsPrivileges(softnet.resolved.path)
  }

  // installs a sudoers rule that lets only this user run only this softnet binary,
  // pinned by its sha-256, as root without a password, after macOS asks for an admin
  // password. it also removes a setuid bit an earlier setup may have left.
  func grantPrivileges() async throws {
    guard let softnet = executable() else {
      throw TartError.sandboxUnavailable(SandboxStatus.missing.problem ?? "")
    }
    let user = NSUserName()
    let paths = [softnet.link.path, softnet.resolved.path]
    guard
      user.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }),
      paths.allSatisfy({ path in
        path.hasPrefix("/")
          && path.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "/._+-".contains($0)) }
      })
    else {
      throw TartError.sandboxUnavailable("The softnet path or user name is unusual.")
    }
    let shell = """
      set -eu
      user="$1"; link="$2"; target="$3"
      # set -e ignores a failing test that is not last in an and-or list.
      [ -f "$target" ] && [ ! -L "$target" ] || exit 1
      [ "$link" = "$target" ] || [ -L "$link" ] || exit 1
      digest=$(/usr/bin/shasum -a 256 "$target") || exit 1
      digest=${digest%% *}
      case "$digest" in "" | *[!0-9a-f]*) exit 1 ;; esac
      [ "${#digest}" -eq 64 ] || exit 1
      rule=/etc/sudoers.d/forgejo-runner-softnet
      staged=$(/usr/bin/mktemp /etc/sudoers.d/.forgejo-runner.XXXXXX)
      trap '/bin/rm -f "$staged"' EXIT
      printf '%s ALL=(root) NOPASSWD: sha256:%s %s, sha256:%s %s\\n' \\
        "$user" "$digest" "$link" "$digest" "$target" > "$staged"
      /usr/sbin/visudo -cq -f "$staged"
      /usr/sbin/chown root:wheel "$staged"
      /bin/chmod 0440 "$staged"
      /bin/mv "$staged" "$rule"
      if [ "$(/usr/bin/stat -f %u "$target")" = 0 ]; then /bin/chmod u-s "$target"; fi
      """
    let script = [
      "on run argv",
      "set command to \"/bin/sh -c \" & quoted form of (item 1 of argv) & \" forgejo\"",
      "repeat with value in rest of argv",
      "set command to command & \" \" & quoted form of (value as text)",
      "end repeat",
      "do shell script command with administrator privileges",
      "end run",
    ]
    _ = try await commands.checked(
      CommandRequest(
        executableURL: URL(filePath: "/usr/bin/osascript"),
        arguments: script.flatMap { ["-e", $0] } + [shell, user] + paths),
      timeout: .seconds(300))
  }

  // the softnet tart finds in PATH, as found and with symlinks resolved.
  private func executable() -> (link: URL, resolved: URL)? {
    let directories = (environment["PATH"] ?? "").split(separator: ":")
    for directory in directories {
      let candidate = URL(filePath: String(directory)).appending(path: "softnet")
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return (candidate, candidate.resolvingSymlinksInPath())
      }
    }
    return nil
  }
}
