import Darwin
import Foundation

nonisolated enum SSDPDiscovery {
  // sends one m-search and returns the location of the first answer from the gateway.
  static func location(gateway: String) -> URL? {
    let socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard socket >= 0 else { return nil }
    defer { close(socket) }
    Socket.disableSIGPIPE(socket)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(1900).bigEndian
    inet_pton(AF_INET, "239.255.255.250", &address.sin_addr)
    let search = Array(
      """
      M-SEARCH * HTTP/1.1\r
      HOST: 239.255.255.250:1900\r
      MAN: "ssdp:discover"\r
      MX: 1\r
      ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r
      \r

      """.utf8)
    let sent = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        sendto(socket, search, search.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard sent == search.count else { return nil }
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
      var timeout = timeval(tv_sec: 0, tv_usec: 250_000)
      setsockopt(
        socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
      var reply = [UInt8](repeating: 0, count: 2_048)
      var sender = sockaddr_in()
      var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
      let count = withUnsafeMutablePointer(to: &sender) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          recvfrom(socket, &reply, reply.count, 0, $0, &senderLength)
        }
      }
      guard count > 0 else { continue }
      var senderText = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
      inet_ntop(AF_INET, &sender.sin_addr, &senderText, socklen_t(senderText.count))
      let senderAddress = String(
        decoding: senderText.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
      guard senderAddress == gateway else { continue }
      let text = String(decoding: reply[0..<count], as: UTF8.self)
      for line in text.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: ":", maxSplits: 1)
        if parts.count == 2,
          parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "location",
          let url = URL(string: parts[1].trimmingCharacters(in: .whitespaces))
        {
          return url
        }
      }
    }
    return nil
  }
}
