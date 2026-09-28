import SwiftUI

struct ImageErrorBar: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Banner(message: message, style: .error)
      Button("Dismiss", systemImage: "xmark", action: onDismiss)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.top, 12)
    }
    .padding(12)
    .background(.bar)
  }
}
