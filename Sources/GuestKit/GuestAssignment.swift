import Foundation

// the connection a guest session runs its single job for. it carries no runner
// token: the host broker behind proxyURL adds the token to every runner call.
public struct GuestAssignment: Equatable, Sendable {
  public let name: String
  public let url: String
  public let uuid: String
  public let labels: [String]
  public let proxyURL: String

  public init(name: String, url: String, uuid: String, labels: [String], proxyURL: String) {
    self.name = name
    self.url = url
    self.uuid = uuid
    self.labels = labels
    self.proxyURL = proxyURL
  }
}
