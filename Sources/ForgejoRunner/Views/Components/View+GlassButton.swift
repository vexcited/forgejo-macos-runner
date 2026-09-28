import SwiftUI

extension View {
  // liquid glass buttons on macOS 26 and later, bordered ones before.
  @ViewBuilder
  func glassButtonStyle(prominent: Bool = false) -> some View {
    if #available(macOS 26, *) {
      if prominent {
        buttonStyle(.glassProminent)
      } else {
        buttonStyle(.glass)
      }
    } else if prominent {
      buttonStyle(.borderedProminent)
    } else {
      buttonStyle(.bordered)
    }
  }
}
