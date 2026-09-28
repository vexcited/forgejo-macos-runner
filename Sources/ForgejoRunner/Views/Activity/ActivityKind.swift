import SwiftUI

// a light classification of free-form activity messages for their icon.
enum ActivityKind {
  case failure
  case warning
  case success
  case info

  init(message: String) {
    let text = message.lowercased()
    if ["fail", "could not", "error", "refus"].contains(where: text.contains) {
      self = .failure
    } else if ["retry", "pausing", "paused", "cancel", "stale", "kept"].contains(
      where: text.contains)
    {
      self = .warning
    } else if ["provisioned", "cloned", "saved", "stopped", "deleted", "finished", "completed"]
      .contains(where: text.contains)
    {
      self = .success
    } else {
      self = .info
    }
  }

  var symbol: String {
    switch self {
    case .failure: "xmark.octagon.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .success: "checkmark.circle.fill"
    case .info: "circle.fill"
    }
  }

  var tint: Color {
    switch self {
    case .failure: .red
    case .warning: .orange
    case .success: .green
    case .info: .secondary
    }
  }
}
