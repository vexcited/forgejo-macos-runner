import SwiftUI

struct TartHomeBar: View {
  let path: String
  let onReveal: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "internaldrive.fill")
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text("Image storage")
          .font(.caption.weight(.medium))
        Text(path)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }
      Spacer()
      Button("Reveal in Finder", systemImage: "folder", action: onReveal)
        .controlSize(.small)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.bar)
  }
}
