import Foundation

// asks ghcr.io, where the image is downloaded from anyway, how large it gets once
// unpacked, so the space can be held before tart starts.
nonisolated enum RegistryImageSize {
  static func unpackedBytes(source: String) async throws -> Int64? {
    guard let (repository, reference) = parse(source) else { return nil }
    let session = URLSession(configuration: .ephemeral)
    defer { session.finishTasksAndInvalidate() }

    var tokenURL = URLComponents(string: "https://ghcr.io/token")!
    tokenURL.queryItems = [URLQueryItem(name: "scope", value: "repository:\(repository):pull")]
    let (tokenData, _) = try await session.data(from: tokenURL.url!)
    let token = try JSONDecoder().decode(RegistryToken.self, from: tokenData).token

    var request = URLRequest(
      url: URL(string: "https://ghcr.io/v2/\(repository)/manifests/\(reference)")!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.oci.image.manifest.v1+json", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return try JSONDecoder().decode(OCIManifest.self, from: data).unpackedBytes
  }

  // ghcr.io/cirruslabs/macos-tahoe-xcode:latest becomes the repository and the tag.
  static func parse(_ source: String) -> (repository: String, reference: String)? {
    guard source.hasPrefix("ghcr.io/") else { return nil }
    let path = source.dropFirst("ghcr.io/".count)
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
    return (String(name), String(reference))
  }
}
