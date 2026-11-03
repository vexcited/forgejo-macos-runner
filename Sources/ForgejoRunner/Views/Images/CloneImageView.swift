import SwiftUI

struct CloneImageView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var source = "ghcr.io/cirruslabs/macos-golden-gate-xcode:latest"
  @State private var name = "golden-gate-xcode"
  @State private var catalog = CatalogState.loading
  @State private var manifest: RegistryManifest?

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(
        title: "Clone an Image",
        subtitle: "Download a registry image or copy a local one."
      )
      Divider()
      CatalogImageList(catalog: catalog, source: $source, name: $name) {
        Task { await loadCatalog() }
      }
      .frame(maxHeight: .infinity)
      Divider()
      Form {
        Section("Registry image") {
          TextField("Source", text: $source)
            .font(.body.monospaced())
          if let reference = RegistryReference(source: source), !reference.isDigest {
            ImageVersionPicker(
              repository: reference.repository, tag: tag(of: reference), manifest: $manifest)
          }
          TextField("Local name", text: $name)
          Text(
            "Images are stored inside the app, apart from anything else on this Mac."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .scrollDisabled(true)
      .fixedSize(horizontal: false, vertical: true)
      Divider()
      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Clone") {
          dismiss()
          Task { await model.cloneImage(source: source, name: name) }
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .disabled(source.isEmpty || name.isEmpty)
      }
      .padding()
    }
    .frame(width: 570, height: 680)
    .task { await loadCatalog() }
  }

  // picking a version rewrites the tag of the source field.
  private func tag(of reference: RegistryReference) -> Binding<String> {
    Binding(
      get: { reference.reference },
      set: { source = reference.with(reference: $0).source }
    )
  }

  private func loadCatalog() async {
    catalog = .loading
    do {
      catalog = .loaded(try await CirrusImageCatalog.fetch())
    } catch {
      catalog = .failed(error.localizedDescription)
    }
  }
}
