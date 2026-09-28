import SwiftUI

// a small neutral tag. the tint only colors the text, for states that need attention.
struct Chip: View {
  let text: String
  var symbol: String?
  var tint: Color = .secondary
  var onRemove: (() -> Void)?

  var body: some View {
    HStack(spacing: 4) {
      if let symbol {
        Image(systemName: symbol)
          .imageScale(.small)
      }
      Text(text)
      if let onRemove {
        Button(action: onRemove) {
          Image(systemName: "xmark")
            .imageScale(.small)
        }
        .buttonStyle(.plain)
        .help("Remove \(text)")
      }
    }
    .font(.caption.weight(.medium))
    .lineLimit(1)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .foregroundStyle(tint)
    .background(Color.hairline.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
  }
}
