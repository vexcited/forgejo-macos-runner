import Foundation

// talks to ghcr.io anonymously, which is enough for the public cirrus labs images.
nonisolated enum RegistryClient {
  private static let manifestType = "application/vnd.oci.image.manifest.v1+json"
  private static let uploadTimeKey = "org.cirruslabs.tart.upload-time"

  // the tags people pick from, without the digest tags some pushes leave behind.
  static func tags(of repository: String) async throws -> [String] {
    try await withSession { session in
      let token = try await token(for: repository, session: session)
      var url = URLComponents(string: "https://\(RegistryReference.host)/v2/\(repository)/tags/list")!
      url.queryItems = [URLQueryItem(name: "n", value: "1000")]
      var request = URLRequest(url: url.url!)
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      let (data, response) = try await session.data(for: request)
      try check(response)
      let tags = try JSONDecoder().decode(RegistryTagList.self, from: data).tags ?? []
      return tags.filter { !$0.hasPrefix("sha256-") && !$0.hasPrefix("sha256:") }
    }
  }

  static func manifest(of reference: RegistryReference) async throws -> RegistryManifest? {
    try await withSession { session in
      try await manifest(of: reference, token: nil, session: session)
    }
  }

  // the newest version tag that points at the same manifest as latest.
  static func latestVersion(of repository: String, tags: [String]) async throws -> (
    manifest: RegistryManifest, version: String?
  )? {
    try await withSession { session in
      let token = try await token(for: repository, session: session)
      let reference = RegistryReference(repository: repository, reference: "latest")
      guard let latest = try await manifest(of: reference, token: token, session: session)
      else { return nil }
      for tag in ImageTag.sorted(tags).filter({ !$0.isLatest }).prefix(10) {
        let candidate = try await manifest(
          of: reference.with(reference: tag.name), token: token, session: session)
        if candidate?.digest == latest.digest {
          return (latest, tag.name)
        }
      }
      return (latest, nil)
    }
  }

  private static func manifest(
    of reference: RegistryReference, token: String?, session: URLSession
  ) async throws -> RegistryManifest? {
    var bearer = token ?? ""
    if token == nil {
      bearer = try await self.token(for: reference.repository, session: session)
    }
    var request = URLRequest(
      url: URL(
        string:
          "https://\(RegistryReference.host)/v2/\(reference.repository)/manifests/\(reference.reference)"
      )!)
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    request.setValue(manifestType, forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
    let manifest = try JSONDecoder().decode(OCIManifest.self, from: data)
    let digest =
      http.value(forHTTPHeaderField: "Docker-Content-Digest")
      ?? (reference.isDigest ? reference.reference : "")
    let uploadedAt = manifest.annotations?[uploadTimeKey].flatMap {
      ISO8601DateFormatter().date(from: $0)
    }
    return RegistryManifest(
      digest: digest, uploadedAt: uploadedAt, unpackedBytes: manifest.unpackedBytes)
  }

  private static func token(for repository: String, session: URLSession) async throws -> String {
    var url = URLComponents(string: "https://\(RegistryReference.host)/token")!
    url.queryItems = [URLQueryItem(name: "scope", value: "repository:\(repository):pull")]
    let (data, response) = try await session.data(from: url.url!)
    try check(response)
    return try JSONDecoder().decode(RegistryToken.self, from: data).token
  }

  private static func check(_ response: URLResponse) throws {
    if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
      throw RegistryError.unexpectedStatus(status)
    }
  }

  private static func withSession<T>(_ body: (URLSession) async throws -> T) async throws -> T {
    let session = URLSession(configuration: .ephemeral)
    defer { session.finishTasksAndInvalidate() }
    return try await body(session)
  }
}
