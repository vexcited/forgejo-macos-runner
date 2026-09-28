import Darwin
import Foundation
import GuestKit

nonisolated enum NATPMPLookup {
  // rfc 6886: a two byte request to udp 5351 of the gateway, answered with the
  // external address in bytes 8 to 11. a connected socket only takes the gateway's
  // replies.
  static func publicIPv4(gateway: String) -> String? {
    let socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard socket >= 0 else { return nil }
    defer { close(socket) }
    Socket.disableSIGPIPE(socket)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(5351).bigEndian
    guard inet_pton(AF_INET, gateway, &address.sin_addr) == 1 else { return nil }
    let connected = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard connected == 0 else { return nil }
    let request: [UInt8] = [0, 0]
    // the rfc retries at 250 ms and doubles the wait each time.
    for milliseconds in [250, 500, 1_000] {
      var timeout = timeval(
        tv_sec: milliseconds / 1_000, tv_usec: Int32(milliseconds % 1_000 * 1_000))
      setsockopt(
        socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
      guard send(socket, request, request.count, 0) == request.count else { return nil }
      var reply = [UInt8](repeating: 0, count: 16)
      let count = recv(socket, &reply, reply.count, 0)
      if count < 0 {
        // a refused port means the router does not speak nat-pmp at all.
        if errno == ECONNREFUSED { return nil }
        continue
      }
      guard count >= 12, reply[0] == 0, reply[1] == 128, reply[2] == 0, reply[3] == 0 else {
        return nil
      }
      let text = reply[8..<12].map(String.init).joined(separator: ".")
      return SessionPreparation.isPublicIPv4(text) ? text : nil
    }
    return nil
  }
}
