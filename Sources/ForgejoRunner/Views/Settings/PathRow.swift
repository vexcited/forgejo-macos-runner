import SwiftUI

struct PathRow: View {
  let title: String
  let url: URL
  let reveal: () -> Void

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) {
        Text(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
        Button("Reveal", systemImage: "arrow.right.circle.fill", action: reveal)
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .help("Reveal in Finder")
      }
    } label: {
      Text(title)
    }
  }
}
