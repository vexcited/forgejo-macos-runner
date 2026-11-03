import SwiftUI

struct ImageRow<Actions: View>: View {
  let image: TartImage
  let isGolden: Bool
  let isProvisioned: Bool
  let isProvisioning: Bool
  // what a session vm wrote on top of the golden image it shares its disk with.
  var writtenBytes: Int64?
  @ViewBuilder var actions: Actions

  private var isDisposable: Bool {
    image.name.hasPrefix(VMName.controllerPrefix)
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(.secondary)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(image.name)
            .font(.headline)
          if isGolden {
            Chip(text: "Golden")
            if isProvisioning {
              Chip(text: "Provisioning")
            } else if isProvisioned {
              Chip(text: "Provisioned")
            } else {
              Chip(text: "Needs provisioning", tint: .orange)
            }
          }
          if isDisposable {
            Chip(text: "Disposable")
          }
        }
        HStack(spacing: 14) {
          Label("\(hostSize) on this Mac", systemImage: "internaldrive")
            .help(hostSizeHelp)
          if writtenBytes == nil {
            Label("\(image.diskSizeGB) GB virtual disk", systemImage: "square.stack.3d.up")
              .help("The size of the disk inside the VM, not the space it takes on this Mac.")
          }
          Label(
            image.source.lowercased() == "oci" ? "Registry" : image.source.capitalized,
            systemImage: "shippingbox")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      HStack(spacing: 6) {
        StatusDot(
          tint: image.isRunning ? .green : .secondary.opacity(0.5))
        Text(image.state.capitalized)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Menu {
        actions
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .help("Image actions")
    }
    .padding(.vertical, 6)
  }

  // a session vm is an apfs clone, it only takes what it wrote since it was cloned.
  private var hostSize: String {
    if let writtenBytes {
      return ByteCountFormatter.string(fromByteCount: writtenBytes, countStyle: .file)
    }
    return "\(image.allocatedSizeGB) GB"
  }

  private var hostSizeHelp: String {
    writtenBytes == nil
      ? "The space this image takes on this Mac."
      : "What this VM wrote since it was cloned. The rest of its disk is shared with the golden image, so it takes no extra space."
  }

  private var symbol: String {
    if isGolden { return "star" }
    if isDisposable { return "hourglass" }
    return "macwindow"
  }
}
