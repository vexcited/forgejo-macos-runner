import SwiftUI

struct ImageRow<Actions: View>: View {
  let image: TartImage
  let isGolden: Bool
  let isProvisioned: Bool
  let isProvisioning: Bool
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
          Label("\(image.allocatedSizeGB) GB used", systemImage: "internaldrive")
          Label("\(image.diskSizeGB) GB disk", systemImage: "square.stack.3d.up")
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

  private var symbol: String {
    if isGolden { return "star" }
    if isDisposable { return "hourglass" }
    return "macwindow"
  }
}
