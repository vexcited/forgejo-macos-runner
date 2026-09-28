import Foundation

nonisolated struct CatalogImage: Identifiable, Equatable, Sendable {
  let name: String
  let publishedAt: Date
  // github only exposes an abbreviated count such as 110k.
  let downloads: String

  var id: String { name }

  var source: String {
    "ghcr.io/cirruslabs/\(name):latest"
  }

  var parsedName: CirrusImageName {
    CirrusImageName(packageName: name)
  }

  var localName: String {
    name.hasPrefix("macos-") ? String(name.dropFirst("macos-".count)) : name
  }
}
