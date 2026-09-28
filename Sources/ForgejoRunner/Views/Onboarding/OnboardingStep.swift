import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
  case welcome
  case sandbox
  case image
  case connections
  case preferences
  case finish

  var id: Self { self }

  var title: String {
    switch self {
    case .welcome: "Welcome"
    case .sandbox: "Sandbox"
    case .image: "Golden Image"
    case .connections: "Connections"
    case .preferences: "Preferences"
    case .finish: "Ready"
    }
  }

  var subtitle: String {
    switch self {
    case .welcome: "Run Forgejo Actions jobs in disposable macOS VMs on this Mac."
    case .sandbox: "Keep every job away from this Mac and your network."
    case .image: "Choose the macOS system your jobs run on."
    case .connections: "Add the Forgejo runners this Mac serves."
    case .preferences: "Choose how Forgejo Runner starts and where it lives."
    case .finish: "Everything is in place."
    }
  }

  var symbol: String {
    switch self {
    case .welcome: "hand.wave"
    case .sandbox: "lock.shield"
    case .image: "shippingbox"
    case .connections: "network"
    case .preferences: "slider.horizontal.3"
    case .finish: "checkmark.seal"
    }
  }

  var previous: Self? { Self(rawValue: rawValue - 1) }
  var next: Self? { Self(rawValue: rawValue + 1) }

  func isComplete(in model: AppModel) -> Bool {
    switch self {
    case .welcome, .preferences: true
    case .sandbox: model.isTartInstalled && model.sandboxStatus == .ready
    case .image: model.isGoldenImageReady && !model.isImageOperationRunning
    case .connections: !model.connections.connections.isEmpty
    case .finish: false
    }
  }

  // why continue is disabled, shown next to the button.
  var blockingHint: String {
    switch self {
    case .sandbox: "Set up the sandbox to continue."
    case .image: ""
    case .connections: "Add a connection to continue."
    case .welcome, .preferences, .finish: ""
    }
  }

  // a step opens once every step before it is complete.
  func isReachable(in model: AppModel) -> Bool {
    Self.allCases.prefix(while: { $0 != self }).allSatisfy { $0.isComplete(in: model) }
  }
}
