import Foundation
import GuestKit

enum BootFirewallStep {
  static func install() throws {
    let environment = ProvisionEnvironment.base
    Console.log("installing the boot firewall that only lets ssh in.")
    for (text, path, mode) in [
      (SessionPreparation.bootFirewallRules, SessionPreparation.bootFirewallRulesPath, "0644"),
      (SessionPreparation.bootFirewallDaemon, SessionPreparation.bootFirewallDaemonPath, "0644"),
    ] {
      let staged = "/private/tmp/forgejo-boot.\(UUID().uuidString)"
      try Data(text.utf8).write(to: URL(filePath: staged), options: .atomic)
      try ProcessRunner.stream(
        "/usr/bin/sudo", ["install", "-o", "root", "-g", "wheel", "-m", mode, staged, path],
        environment: environment)
      try? FileManager.default.removeItem(atPath: staged)
    }
    _ = ProcessRunner.capture(
      "/usr/bin/sudo",
      ["/bin/launchctl", "bootout", "system/\(SessionPreparation.bootFirewallLabel)"],
      environment: environment)
    try ProcessRunner.stream(
      "/usr/bin/sudo",
      ["/bin/launchctl", "bootstrap", "system", SessionPreparation.bootFirewallDaemonPath],
      environment: environment)
  }
}
