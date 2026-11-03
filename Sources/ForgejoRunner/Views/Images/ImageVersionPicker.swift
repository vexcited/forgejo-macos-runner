import SwiftUI

// the tags a registry repository publishes, with when the picked one was uploaded.
struct ImageVersionPicker: View {
  let repository: String
  @Binding var tag: String
  @Binding var manifest: RegistryManifest?
  @State private var tags: [ImageTag] = []
  @State private var latestVersion: String?
  @State private var failure: String?

  var body: some View {
    Picker("Version", selection: $tag) {
      ForEach(choices, id: \.name) { choice in
        Text(label(for: choice)).tag(choice.name)
      }
    }
    .disabled(tags.isEmpty)
    .task(id: repository) { await loadTags() }
    .task(id: [repository, tag]) { await loadManifest() }
    Text(detail)
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  // the typed tag stays selectable even when the registry does not list it.
  private var choices: [ImageTag] {
    tags.contains { $0.name == tag } ? tags : [ImageTag(tag)] + tags
  }

  private func label(for choice: ImageTag) -> String {
    if choice.isLatest {
      return latestVersion.map { "Latest (\($0))" } ?? "Latest"
    }
    return choice.isPrerelease ? "\(choice.name) (pre-release)" : choice.name
  }

  private var detail: String {
    if let failure { return failure }
    guard let manifest else { return tags.isEmpty ? "Loading versions..." : " " }
    let size = ByteCountFormatter.string(fromByteCount: manifest.unpackedBytes, countStyle: .file)
    guard let uploadedAt = manifest.uploadedAt else { return "\(size) once downloaded." }
    let date = uploadedAt.formatted(date: .abbreviated, time: .omitted)
    return "Published \(date), \(size) once downloaded."
  }

  private func loadTags() async {
    tags = []
    latestVersion = nil
    failure = nil
    do {
      let names = try await RegistryClient.tags(of: repository)
      guard !Task.isCancelled else { return }
      tags = ImageTag.sorted(names)
      let latest = try? await RegistryClient.latestVersion(of: repository, tags: names)
      guard !Task.isCancelled else { return }
      latestVersion = latest?.version
    } catch where Task.isCancelled {
    } catch {
      failure = "Could not list the versions: \(error.localizedDescription)"
    }
  }

  private func loadManifest() async {
    manifest = nil
    let reference = RegistryReference(repository: repository, reference: tag)
    let loaded = try? await RegistryClient.manifest(of: reference)
    guard !Task.isCancelled else { return }
    manifest = loaded
  }
}
