import SwiftUI

struct UpdateImageView: View {
  // room for tart's metadata on top of the image, as the download reservation keeps.
  private static let margin: Int64 = 2_000_000_000

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let target: ImageUpdateTarget
  @State private var tag = "latest"
  @State private var manifest: RegistryManifest?

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(
        title: "Update \(name)",
        subtitle: "Download another version from \(RegistryReference.host)/\(target.repository)."
      )
      Divider()
      Form {
        Section {
          ImageVersionPicker(repository: target.repository, tag: $tag, manifest: $manifest)
          if let installed {
            LabeledContent("Installed", value: installed)
          }
        }
        Section {
          Label(spaceMessage, systemImage: spaceSymbol)
            .foregroundStyle(space == .keepsCurrent ? Color.secondary : .orange)
          if isGolden {
            Text("\(name) is the golden image, it is provisioned again once downloaded.")
              .foregroundStyle(.secondary)
          }
        }
        .font(.callout)
      }
      .formStyle(.grouped)
      Divider()
      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(space == .replacesCurrent ? "Delete and Update" : "Update") {
          dismiss()
          let source = RegistryReference(repository: target.repository, reference: tag).source
          let keepingCurrent = space == .keepsCurrent
          Task { await model.updateImage(name, to: source, keepingCurrent: keepingCurrent) }
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .disabled(manifest == nil || space == .tooLarge || model.coordinator.isRunning)
      }
      .padding()
    }
    .frame(width: 540, height: 400)
  }

  private var name: String { target.image.name }

  private var isGolden: Bool { model.preferences.selectedImage == name }

  private var installed: String? {
    guard let origin = model.preferences.origin(of: name) else { return nil }
    let version = origin.version ?? origin.tag
    guard let uploadedAt = origin.uploadedAt else { return version }
    return "\(version), published \(uploadedAt.formatted(date: .abbreviated, time: .omitted))"
  }

  private enum Space {
    case unknown
    case keepsCurrent
    case replacesCurrent
    case tooLarge
  }

  private var available: Int64 {
    let values = try? model.paths.appSupport.resourceValues(forKeys: [
      .volumeAvailableCapacityKey
    ])
    return Int64(values?.volumeAvailableCapacity ?? 0)
  }

  private var needed: Int64 {
    (manifest?.unpackedBytes ?? 0) + Self.margin
  }

  private var space: Space {
    guard manifest != nil else { return .unknown }
    if needed <= available { return .keepsCurrent }
    let current = Int64(target.image.allocatedSizeGB) * 1_000_000_000
    return needed <= available + current ? .replacesCurrent : .tooLarge
  }

  private var spaceMessage: String {
    let format = { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    switch space {
    case .unknown:
      return "Checking the space the new version needs..."
    case .keepsCurrent:
      return "\(name) stays usable until the new version is ready."
    case .replacesCurrent:
      return
        "Not enough free space to keep both: \(format(needed)) needed, \(format(available)) free. \(name) is deleted before the download starts."
    case .tooLarge:
      return
        "Not enough free space, even after deleting \(name): \(format(needed)) needed, \(format(available)) free."
    }
  }

  private var spaceSymbol: String {
    space == .keepsCurrent || space == .unknown ? "internaldrive" : "exclamationmark.triangle"
  }
}
