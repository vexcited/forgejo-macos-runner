import Foundation
import GuestKit

enum SSHDHardeningStep {
  static func apply() throws {
    let environment = ProvisionEnvironment.base
    Console.log("enforcing public-key-only ssh authentication.")
    let sshdTemp = "/private/tmp/forgejo-sshd.\(UUID().uuidString)"
    try Data((SSHHardening.configText + "\n").utf8).write(
      to: URL(filePath: sshdTemp), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sshdTemp)
    try ProcessRunner.stream(
      "/usr/bin/sudo", ["install", "-d", "-m", "0755", "/etc/ssh/sshd_config.d"],
      environment: environment)
    try ProcessRunner.stream(
      "/usr/bin/sudo",
      ["install", "-m", "0644", sshdTemp, "/etc/ssh/sshd_config.d/\(SSHHardening.configFileName)"],
      environment: environment)
    try? FileManager.default.removeItem(atPath: sshdTemp)
    try ProcessRunner.stream("/usr/bin/sudo", ["/usr/sbin/sshd", "-t"], environment: environment)
    guard
      let effective = ProcessRunner.capture(
        "/usr/bin/sudo", ["/usr/sbin/sshd", "-T"], environment: environment),
      effective.status == 0
    else {
      throw ProvisionFailure(message: "could not read the effective sshd configuration.", code: 1)
    }
    let effectiveLines = Set(
      effective.output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
    for setting in SSHHardening.requiredEffectiveSettings where !effectiveLines.contains(setting) {
      throw ProvisionFailure(message: "sshd did not apply \(setting).", code: 1)
    }
    Console.log("ssh now requires the dedicated controller public key.")
  }
}
