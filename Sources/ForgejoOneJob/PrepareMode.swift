import Foundation
import GuestKit

// runs as root through the tart guest agent before any job: fresh ssh host keys and
// public dns resolvers, see SessionPreparation.
enum PrepareMode {
  static func run(_ arguments: [String]) -> Never {
    guard let dnsServers = SessionPreparation.dnsServers(from: Array(arguments.dropFirst())),
      geteuid() == 0
    else {
      Console.error("usage: sudo forgejo-one-job --prepare <public-dns-ipv4>...")
      exit(64)
    }
    let hostKey = replaceHostKeys()
    setDNSServers(dnsServers)
    loadFirewall()

    print("\(SessionPreparation.hostKeyMarker) \(hostKey)")
    exit(0)
  }

  private static func replaceHostKeys() -> String {
    let fileManager = FileManager.default
    let hostKeys =
      (try? fileManager.contentsOfDirectory(atPath: SessionPreparation.hostKeyDirectory)) ?? []
    for name in hostKeys where name.hasPrefix("ssh_host_") && name.contains("key") {
      do {
        try fileManager.removeItem(atPath: "\(SessionPreparation.hostKeyDirectory)/\(name)")
      } catch {
        Console.error("could not remove the inherited host key \(name): \(error).")
        exit(1)
      }
    }
    guard
      let keygen = ProcessRunner.capture(
        "/usr/bin/ssh-keygen",
        [
          "-q", "-t", "ed25519", "-N", "", "-C", "forgejo-session", "-f",
          SessionPreparation.hostKeyPath,
        ]),
      keygen.status == 0,
      let publicKey = try? String(
        contentsOfFile: SessionPreparation.hostKeyPath + ".pub", encoding: .utf8),
      let hostKey = SessionPreparation.hostKey(
        inOutput: "\(SessionPreparation.hostKeyMarker) "
          + publicKey.split(separator: " ").prefix(2).joined(separator: " "))
    else {
      Console.error("could not generate the session host key.")
      exit(1)
    }
    return hostKey
  }

  private static func setDNSServers(_ dnsServers: [String]) {
    guard
      let services = ProcessRunner.capture("/usr/sbin/networksetup", ["-listallnetworkservices"]),
      services.status == 0
    else {
      Console.error("could not list the network services.")
      exit(1)
    }
    // the first line is a legend, and a leading asterisk marks a disabled service.
    for service in services.output.split(whereSeparator: \.isNewline).dropFirst()
    where !service.hasPrefix("*") {
      guard
        let result = ProcessRunner.capture(
          "/usr/sbin/networksetup", ["-setdnsservers", String(service)] + dnsServers),
        result.status == 0
      else {
        Console.error("could not set the dns servers of \(service).")
        exit(1)
      }
    }
    _ = ProcessRunner.capture("/usr/bin/dscacheutil", ["-flushcache"])
    _ = ProcessRunner.capture("/usr/bin/killall", ["-HUP", "mDNSResponder"])
  }

  private static func loadFirewall() {
    let fileManager = FileManager.default
    guard let route = ProcessRunner.capture("/sbin/route", ["-n", "get", "default"]),
      let gateway = SessionPreparation.gateway(inRouteOutput: route.output),
      let rules = SessionPreparation.firewallRules(gateway: gateway)
    else {
      Console.error("could not find the vmnet gateway for the guest firewall.")
      exit(1)
    }
    let rulesFile = "/private/tmp/forgejo-pf.\(UUID().uuidString)"
    guard
      fileManager.createFile(
        atPath: rulesFile, contents: Data(rules.utf8), attributes: [.posixPermissions: 0o600])
    else {
      Console.error("could not write the guest firewall rules.")
      exit(1)
    }
    let loaded = ProcessRunner.capture(
      "/sbin/pfctl", ["-a", SessionPreparation.firewallAnchor, "-f", rulesFile])
    try? fileManager.removeItem(atPath: rulesFile)
    guard loaded?.status == 0,
      let enabled = ProcessRunner.capture("/sbin/pfctl", ["-E"]), enabled.status == 0
    else {
      Console.error("could not load the guest firewall.")
      exit(1)
    }
  }
}
