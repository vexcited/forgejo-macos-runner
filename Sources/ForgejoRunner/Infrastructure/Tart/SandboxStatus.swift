import Foundation

nonisolated enum SandboxStatus: Equatable, Sendable {
  case ready
  case missing
  case outdated(String)
  case needsPrivileges(String)

  var problem: String? {
    switch self {
    case .ready:
      nil
    case .missing:
      "Part of the sandbox is missing. Run brew install openai/tools/tart, then check again in Settings > VM."
    case .outdated:
      "The sandbox tools are out of date. Run brew uninstall cirruslabs/cli/tart cirruslabs/cli/softnet, then brew install openai/tools/tart, then check again in Settings > VM."
    case .needsPrivileges:
      "The sandbox needs your admin password once. Choose Set Up Sandbox in Settings > VM."
    }
  }
}
