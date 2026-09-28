import Foundation

nonisolated enum AppConfigurationError: LocalizedError, Sendable {
  case noImageSelected
  case noConnections
  case reservedGoldenImage
  case invalidVMPrefix
  case invalidDNSServers

  var errorDescription: String? {
    switch self {
    case .noImageSelected: "Select a provisioned Tart image first."
    case .noConnections: "Add at least one Forgejo runner connection first."
    case .reservedGoldenImage: "Select a golden image outside the reserved fjmr- namespace."
    case .invalidVMPrefix: "The VM prefix contains unsupported characters."
    case .invalidDNSServers: "Enter one to four public IPv4 DNS servers for the sandbox."
    }
  }
}
