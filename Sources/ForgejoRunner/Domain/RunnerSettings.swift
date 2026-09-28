import Foundation

nonisolated struct RunnerSettings: Equatable, Sendable {
  let goldenImage: String
  let vmPrefix: String
  let dnsServers: [String]
  let bootTimeoutSeconds: Int
  let sshTimeoutSeconds: Int
  let runnerSessionTimeoutSeconds: Int
  let retryDelaySeconds: Int
  let preventSleep: Bool
  let runnerVersion: String
  let homeDirectory: URL
  let tartHome: URL
}
