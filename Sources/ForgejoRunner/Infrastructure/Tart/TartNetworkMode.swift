import Foundation

// every vm runs behind softnet, which keeps it off the lan and away from other vms,
// drops ipv6 and multicast-free fallbacks aside, and stops address spoofing.
nonisolated enum TartNetworkMode: Equatable, Sendable {
  // a pristine golden image being provisioned over the guest agent: nothing may
  // connect into it, while it still reaches the internet and the vmnet dns.
  case provisioning
  // a runner session: see run(name:networkMode:).
  case sandboxed(blockedNetworks: [String])
}
