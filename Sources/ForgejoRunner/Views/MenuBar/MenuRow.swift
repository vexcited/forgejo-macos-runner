import SwiftUI

// a full width row that highlights on hover like a native menu item.
struct MenuRow: View {
  let title: String
  let symbol: String
  let shortcut: String
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .frame(width: 18)
        Text(title)
        Spacer()
        Text("\u{2318}\(shortcut)")
          .foregroundStyle(
            isHovered ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.tertiary))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .foregroundStyle(isHovered ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
      .background(
        isHovered ? Color.accentColor : .clear,
        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
