import SwiftUI

struct ActivityRow: View {
  let entry: ActivityEntry
  var compact = false

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: kind.symbol)
        .foregroundStyle(kind.tint)
        .imageScale(.small)
        .frame(width: 16)
      Text(entry.message)
        .lineLimit(compact ? 1 : nil)
        .truncationMode(.tail)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(entry.date, format: .dateTime.hour().minute().second())
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .font(compact ? .callout : .body)
  }

  private var kind: ActivityKind {
    ActivityKind(message: entry.message)
  }
}
