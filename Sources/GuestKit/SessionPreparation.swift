import Foundation

// the root step the host runs through the tart guest agent before any job, over a
// channel no network peer can reach. it replaces the ssh host keys every clone
// inherits from the golden image, which any earlier job could have read, and moves
// dns off the vmnet gateway so the sandbox can block the host entirely.
public enum SessionPreparation {
  public static let hostKeyMarker = "FORGEJO_SESSION_HOST_KEY"
  public static let hostKeyDirectory = "/etc/ssh"
  public static let hostKeyPath = "/etc/ssh/ssh_host_ed25519_key"

  // the dns resolvers passed after --prepare, which must be public ipv4 addresses
  // because the sandbox only lets the vm reach globally routable addresses.
  public static func dnsServers(from arguments: [String]) -> [String]? {
    guard (1...4).contains(arguments.count),
      arguments.allSatisfy(isPublicIPv4)
    else { return nil }
    return arguments
  }

  public static func isPublicIPv4(_ value: String) -> Bool {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return false }
    var octets: [Int] = []
    for part in parts {
      guard (1...3).contains(part.count), part.allSatisfy({ ("0"..."9").contains($0) }),
        let octet = Int(part), octet <= 255, part == String(octet)
      else { return false }
      octets.append(octet)
    }
    let (a, b) = (octets[0], octets[1])
    let isPrivateOrReserved =
      a == 0 || a == 10 || a == 127 || a >= 224
      || (a == 100 && (64...127).contains(b))
      || (a == 169 && b == 254)
      || (a == 172 && (16...31).contains(b))
      || (a == 192 && b == 168)
      || (a == 192 && b == 0 && octets[2] == 0)
      || (a == 198 && (18...19).contains(b))
    return !isPrivateOrReserved
  }

  // macOS pf evaluates every anchor under com.apple/, so these rules apply without
  // touching /etc/pf.conf.
  public static let firewallAnchor = "com.apple/250.ForgejoRunner"

  // lets nothing into the vm but the app's ssh from the vmnet gateway, dhcp replies
  // and loopback, so no process on the host reaches the job's services either.
  // outbound traffic keeps state, so its replies still come in.
  public static func firewallRules(gateway: String) -> String? {
    guard isIPv4(gateway) else { return nil }
    return rules(sshSource: gateway)
  }

  // the same rules before the gateway is known. every clone loads them at boot, so no
  // service is reachable before its session is prepared, and ssh only takes the
  // controller key.
  public static let bootFirewallRules = rules(sshSource: "any")
  public static let bootFirewallRulesPath = "/private/etc/forgejo-runner-pf.rules"
  public static let bootFirewallLabel = "com.vexcited.forgejo.runner.firewall"
  public static let bootFirewallDaemonPath =
    "/Library/LaunchDaemons/\(bootFirewallLabel).plist"
  public static let bootFirewallDaemon = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>\(bootFirewallLabel)</string>
      <key>ProgramArguments</key>
      <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>/sbin/pfctl -q -f /etc/pf.conf; /sbin/pfctl -q -a \(firewallAnchor) -f \(bootFirewallRulesPath) &amp;&amp; /sbin/pfctl -q -E</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
    </plist>

    """

  private static func rules(sshSource: String) -> String {
    """
    pass out quick all keep state
    pass in quick on lo0 all
    pass in quick inet proto udp from any port 67 to any port 68
    pass in quick inet proto tcp from \(sshSource) to any port 22 flags S/SA keep state
    block drop in quick all

    """
  }

  // the gateway from `route -n get default` output.
  public static func gateway(inRouteOutput output: String) -> String? {
    for line in output.split(whereSeparator: \.isNewline) {
      let fields = line.split(separator: ":", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      if fields.count == 2, fields[0] == "gateway", isIPv4(fields[1]) {
        return fields[1]
      }
    }
    return nil
  }

  static func isIPv4(_ value: String) -> Bool {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    return parts.count == 4
      && parts.allSatisfy { part in
        (1...3).contains(part.count) && part.allSatisfy({ ("0"..."9").contains($0) })
          && Int(part).map { $0 <= 255 && String($0) == part } == true
      }
  }

  // the host key line the helper prints, parsed back on the host.
  public static func hostKey(inOutput output: String) -> String? {
    for line in output.split(whereSeparator: \.isNewline) {
      let fields = line.split(separator: " ")
      guard fields.count == 3, fields[0] == hostKeyMarker, fields[1] == "ssh-ed25519",
        fields[2].count <= 128,
        fields[2].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+/=".contains($0)) })
      else { continue }
      return "ssh-ed25519 \(fields[2])"
    }
    return nil
  }
}
