import Foundation

// the macos releases cirrus labs publishes images for.
nonisolated enum MacOSRelease: String, CaseIterable, Sendable {
  case goldenGate = "golden-gate"
  case tahoe
  case sequoia
  case sonoma
  case ventura
  case monterey

  var name: String {
    switch self {
    case .goldenGate: "Golden Gate"
    case .tahoe: "Tahoe"
    case .sequoia: "Sequoia"
    case .sonoma: "Sonoma"
    case .ventura: "Ventura"
    case .monterey: "Monterey"
    }
  }

  // the release icon in the MacOSReleases asset catalog.
  var assetName: String {
    "macos-\(rawValue)"
  }

  var version: Int {
    switch self {
    case .goldenGate: 27
    case .tahoe: 26
    case .sequoia: 15
    case .sonoma: 14
    case .ventura: 13
    case .monterey: 12
    }
  }
}
