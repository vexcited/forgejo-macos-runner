import Foundation

// the basic auth pair the guest runner must present to open a tunnel.
@MainActor
struct BrokerProxyCredentials {
  let username = "runner"
  let password: String

  var authorization: String {
    "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
  }

  // the proxy url for the guest runner, whose ssh reverse tunnel listens on guestPort.
  func proxyURL(guestPort: UInt16) -> String {
    "http://\(username):\(password)@127.0.0.1:\(guestPort)"
  }

  func accepts(_ header: String?) -> Bool {
    Self.constantTimeEquals(header, authorization)
  }

  private static func constantTimeEquals(_ candidate: String?, _ expected: String) -> Bool {
    let candidate = Array((candidate ?? "").utf8)
    let expected = Array(expected.utf8)
    var difference = UInt8(candidate.count == expected.count ? 0 : 1)
    for index in expected.indices {
      difference |= expected[index] ^ (index < candidate.count ? candidate[index] : 0)
    }
    return difference == 0
  }
}
