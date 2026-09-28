import Foundation
import GuestKit

// the guest side lives in GuestKit/RunnerConnectionStream.swift. no runner token is
// sent: the guest runner reaches forgejo through the broker at proxyURL.
nonisolated enum RunnerConnectionStream {
  static let guestValidationMarker = RunnerSessionProtocol.validationMarker

  static func encode(connection: RunnerConnection, proxyURL: String) -> Data {
    var fields = [
      "FJMR2",
      connection.name,
      connection.url.absoluteString,
      connection.uuid.uuidString.lowercased(),
      String(connection.labels.count),
    ]
    fields.append(contentsOf: connection.labels)
    fields.append(proxyURL)
    return Data((fields.joined(separator: "\n") + "\n").utf8)
  }
}
