import SwiftUI

struct Banner: View {
  enum Style {
    case warning
    case error
    case info

    var tint: Color {
      switch self {
      case .warning: .orange
      case .error: .red
      case .info: .blue
      }
    }

    var symbol: String {
      switch self {
      case .warning: "exclamationmark.triangle.fill"
      case .error: "xmark.octagon.fill"
      case .info: "info.circle.fill"
      }
    }
  }

  let message: String
  var style: Style = .warning

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: style.symbol)
        .foregroundStyle(style.tint)
      Text(message)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.callout)
    .padding(12)
    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(Color.hairline, lineWidth: 1)
    }
  }
}
