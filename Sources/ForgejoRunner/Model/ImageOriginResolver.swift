import Foundation

// records where a registry download comes from, right before tart pulls it.
nonisolated enum ImageOriginResolver {
  static func resolve(source: String) async -> ImageOrigin? {
    guard let reference = RegistryReference(source: source),
      let manifest = try? await RegistryClient.manifest(of: reference)
    else { return nil }
    var version = ImageTag(reference.reference).isVersion ? reference.reference : nil
    if version == nil, let tags = try? await RegistryClient.tags(of: reference.repository),
      let latest = try? await RegistryClient.latestVersion(
        of: reference.repository, tags: tags),
      latest.manifest.digest == manifest.digest
    {
      version = latest.version
    }
    return ImageOrigin(
      repository: reference.repository, tag: reference.reference, version: version,
      digest: manifest.digest, uploadedAt: manifest.uploadedAt)
  }
}
