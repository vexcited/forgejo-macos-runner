import SwiftUI

// the one state the sandbox step shows at a time.
enum OnboardingSandboxPhase: Hashable {
  case checking
  case tartMissing
  case needsPrivileges
  case needsAttention(String)
  case ready

  @MainActor
  init(model: AppModel) {
    guard let status = model.sandboxStatus else {
      self = .checking
      return
    }
    if !model.isTartInstalled {
      self = .tartMissing
      return
    }
    switch status {
    case .ready: self = .ready
    case .needsPrivileges: self = .needsPrivileges
    case .missing, .outdated: self = .needsAttention(status.problem ?? "")
    }
  }

  var symbol: String {
    switch self {
    case .checking: "shield"
    case .ready: "checkmark.shield.fill"
    case .needsPrivileges: "lock.shield"
    case .tartMissing, .needsAttention: "exclamationmark.shield"
    }
  }

  var tint: Color {
    switch self {
    case .checking: .secondary
    case .ready: .green
    case .needsPrivileges: .accentColor
    case .tartMissing, .needsAttention: .orange
    }
  }

  var title: String {
    switch self {
    case .checking: "Checking..."
    case .tartMissing: "One install needed"
    case .needsPrivileges: "One admin password"
    case .needsAttention: "Something needs fixing"
    case .ready: "You're all set"
    }
  }

  var message: String {
    switch self {
    case .checking:
      "Making sure this Mac is ready."
    case .tartMissing:
      "Run this command in Terminal, then click Check Again."
    case .needsPrivileges:
      "Jobs are kept away from this Mac and your network. macOS asks for your password once to turn that on."
    case .needsAttention(let problem):
      problem
    case .ready:
      "Jobs can reach the internet, but never this Mac, your network or each other."
    }
  }
}
