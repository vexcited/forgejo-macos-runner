import Foundation

// a ghcr.io image reference split into its repository and its tag or digest.
nonisolated struct RegistryReference: Equatable, Sendable {
  static let host = "ghcr.io"

  let repository: String
  let reference: String

  init(repository: String, reference: String) {
    self.repository = repository
    self.reference = reference
  }

  // ghcr.io/cirruslabs/macos-tahoe-xcode:latest becomes the repository and the tag.
  init?(source: String) {
    guard source.hasPrefix("\(Self.host)/") else { return nil }
    let path = source.dropFirst(Self.host.count + 1)
    let name: Substring
    let reference: Substring
    if let at = path.firstIndex(of: "@") {
      name = path[..<at]
      reference = path[path.index(after: at)...]
    } else if let colon = path.lastIndex(of: ":"), !path[colon...].contains("/") {
      name = path[..<colon]
      reference = path[path.index(after: colon)...]
    } else {
      name = path
      reference = "latest"
    }
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._-/:")
    guard !name.isEmpty, !reference.isEmpty,
      name.allSatisfy({ allowed.contains($0) && $0 != ":" }),
      reference.lowercased().allSatisfy({ allowed.contains($0) && $0 != "/" })
    else { return nil }
    repository = String(name)
    self.reference = String(reference)
  }

  var isDigest: Bool {
    reference.hasPrefix("sha256:")
  }

  var source: String {
    "\(Self.host)/\(repository)\(isDigest ? "@" : ":")\(reference)"
  }

  func with(reference: String) -> RegistryReference {
    RegistryReference(repository: repository, reference: reference)
  }
}
