import Foundation

nonisolated struct GoldenImageSettings: Sendable {
  var image: String
  var runnerVersion: String
  var xcodeApplicationPath: String
  var bootTimeoutSeconds: Int
  // how long the tart guest agent may take to answer after the vm has an address.
  var guestAgentTimeoutSeconds: Int
  var adminUser: String = "admin"
}
