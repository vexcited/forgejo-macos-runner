import CryptoKit
import Foundation

// mirrors how tart normalizes a registry reference so the app can predict the
// deterministic temporary directory that a resumable pull writes into.
nonisolated struct TartRemoteName: Equatable, Sendable {
  let host: String
  let namespace: String
  let reference: String

  init?(_ name: String) {
    guard let slash = name.firstIndex(of: "/") else { return nil }
    let host = String(name[..<slash])
    let path = String(name[name.index(after: slash)...])
    guard Self.isRegistryHost(host), !path.isEmpty else { return nil }
    let namespace: String
    let reference: String
    if let at = path.firstIndex(of: "@") {
      namespace = String(path[..<at])
      reference = String(path[at...])
      guard reference.hasPrefix("@sha256:"), reference.count > "@sha256:".count else { return nil }
    } else {
      let lastComponentStart =
        path.lastIndex(of: "/").map { path.index(after: $0) } ?? path.startIndex
      if let colon = path[lastComponentStart...].firstIndex(of: ":") {
        namespace = String(path[..<colon])
        reference = String(path[colon...])
        guard reference.count > 1 else { return nil }
      } else {
        namespace = path
        reference = ":latest"
      }
    }
    guard !namespace.isEmpty,
      !namespace.split(separator: "/", omittingEmptySubsequences: false).contains(where: \.isEmpty)
    else {
      return nil
    }
    self.host = host
    self.namespace = namespace
    self.reference = reference
  }

  var description: String {
    "\(host)/\(namespace)\(reference)"
  }

  // tart derives its resumable pull directory from the md5 of the normalized name.
  var temporaryDirectoryName: String {
    Insecure.MD5.hash(data: Data(description.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  private static func isRegistryHost(_ host: String) -> Bool {
    let hostname = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? host
    guard !hostname.isEmpty else { return false }
    return hostname == "localhost" || hostname.contains(".") || host.contains(":")
  }
}
