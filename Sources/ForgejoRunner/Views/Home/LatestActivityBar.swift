import SwiftUI

// the newest activity line along the bottom edge, opening the full log when clicked.
struct LatestActivityBar: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button {
      openWindow(id: AppPanel.activity.rawValue)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "text.alignleft")
          .foregroundStyle(.tertiary)
        // a new line pushes the previous one up and out, like a ticker.
        ZStack(alignment: .leading) {
          Text(latest?.message ?? "No activity yet")
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(latest?.id)
            .transition(
              .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)))
        }
        .clipped()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .font(.callout)
      .padding(.horizontal, 18)
      .frame(height: 44)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .background(.bar)
    .overlay(alignment: .top) { Divider() }
    .animation(.smooth(duration: 0.35), value: latest?.id)
    .help("Show all activity")
  }

  private var latest: ActivityEntry? {
    model.activity.entries.last
  }
}
