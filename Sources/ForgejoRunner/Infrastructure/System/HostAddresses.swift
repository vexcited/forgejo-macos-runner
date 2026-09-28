import Darwin
import Foundation
import GuestKit

nonisolated enum HostAddresses {
  // public ipv4 networks this mac sits on, as cidr blocks. softnet lets a vm reach any
  // public address, and a public address on this mac or its lan leads straight back
  // to their services.
  static func publicNetworks() -> [String] {
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0, let first = list else { return [] }
    defer { freeifaddrs(list) }
    var networks: Set<String> = []
    for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
      guard let address = entry.pointee.ifa_addr,
        address.pointee.sa_family == sa_family_t(AF_INET),
        let host = ipv4(address), let text = dotted(host),
        SessionPreparation.isPublicIPv4(text)
      else { continue }
      networks.insert("\(text)/32")
      // a netmask this wide is not a real lan, so only the address itself is blocked.
      let prefix = entry.pointee.ifa_netmask.map(prefixLength) ?? 32
      guard (8..<32).contains(prefix) else { continue }
      if let network = dotted(host & (UInt32.max << (32 - prefix))) {
        networks.insert("\(network)/\(prefix)")
      }
    }
    return networks.sorted()
  }

  // every public network a session vm must never reach, including the router's own
  // public address, which a router that loops traffic back would turn into the lan.
  static func sandboxBlocks() async -> SandboxBlocks {
    let router = await RouterAddress.publicIPv4()
    var networks = Set(publicNetworks())
    if let router { networks.insert("\(router)/32") }
    return SandboxBlocks(networks: networks, routerAddressKnown: router != nil)
  }

  private static func ipv4(_ address: UnsafeMutablePointer<sockaddr>) -> UInt32? {
    guard address.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
    return address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
      UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
    }
  }

  // netmasks carry no address family and are often cut short after their last
  // nonzero byte, so the mask is read byte by byte up to the recorded length.
  private static func prefixLength(_ mask: UnsafeMutablePointer<sockaddr>) -> Int {
    let length = Int(mask.pointee.sa_len)
    let bytes = UnsafeRawPointer(mask)
    var value: UInt32 = 0
    for index in 0..<4 {
      let offset = MemoryLayout<sockaddr_in>.offset(of: \.sin_addr)! + index
      let byte = offset < length ? bytes.load(fromByteOffset: offset, as: UInt8.self) : 0
      value = value << 8 | UInt32(byte)
    }
    return (~value).leadingZeroBitCount
  }

  private static func dotted(_ value: UInt32) -> String? {
    var address = in_addr(s_addr: value.bigEndian)
    var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &text, socklen_t(text.count)) != nil else { return nil }
    return String(decoding: text.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }
}
