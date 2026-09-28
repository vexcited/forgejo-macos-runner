import SwiftUI

// the secondary screens, opened as sheets over the status window.
enum AppPanel: String, CaseIterable, Identifiable {
  case connections
  case images
  case activity

  var id: Self { self }

  var title: String {
    switch self {
    case .connections: "Connections"
    case .images: "Images"
    case .activity: "Activity"
    }
  }

  var symbol: String {
    switch self {
    case .connections: "network"
    case .images: "shippingbox"
    case .activity: "list.bullet.rectangle"
    }
  }
}
