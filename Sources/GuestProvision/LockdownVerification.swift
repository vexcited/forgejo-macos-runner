import Foundation
import GuestKit

enum LockdownVerification {
  // provisioning fails unless screen sharing stays disabled across boots, nothing
  // listens for screen sharing or remote management, and the boot firewall is on.
  static func verify() throws {
    let environment = ProvisionEnvironment.base
    guard
      let disabled = ProcessRunner.capture(
        "/usr/bin/sudo", ["/bin/launchctl", "print-disabled", "system"],
        environment: environment),
      disabled.status == 0,
      disabled.output.split(whereSeparator: \.isNewline).contains(where: { line in
        line.contains("\"com.apple.screensharing\"")
          && (line.hasSuffix("=> disabled") || line.hasSuffix("=> true"))
      })
    else {
      throw ProvisionFailure(message: "screen sharing is still enabled.", code: 1)
    }
    for filter in [["-iTCP:5900", "-iTCP:3283", "-sTCP:LISTEN"], ["-iUDP:3283"]] {
      // terse output is one pid per line, lsof exits 1 when nothing matches.
      guard
        let listeners = ProcessRunner.capture(
          "/usr/bin/sudo", ["/usr/sbin/lsof", "-nPtw"] + filter, environment: environment)
      else {
        throw ProvisionFailure(message: "could not list listening sockets.", code: 1)
      }
      let pids = listeners.output.split(whereSeparator: \.isNewline).filter {
        !$0.isEmpty && $0.allSatisfy(\.isNumber)
      }
      guard pids.isEmpty else {
        throw ProvisionFailure(
          message:
            "screen sharing or remote management still listens (pid \(pids.joined(separator: ", ")))",
          code: 1)
      }
    }
    // launchd starts the boot firewall asynchronously after bootstrap.
    for attempt in 1...20 {
      if let info = ProcessRunner.capture(
        "/usr/bin/sudo", ["/sbin/pfctl", "-s", "info"], environment: environment),
        info.output.contains("Status: Enabled"),
        let rules = ProcessRunner.capture(
          "/usr/bin/sudo",
          ["/sbin/pfctl", "-a", SessionPreparation.firewallAnchor, "-s", "rules"],
          environment: environment),
        rules.output.contains("block drop in quick all")
      {
        return
      }
      if attempt < 20 { sleep(1) }
    }
    throw ProvisionFailure(message: "the boot firewall is not active.", code: 1)
  }
}
