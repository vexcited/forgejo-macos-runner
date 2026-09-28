import SwiftUI

struct StatusDot: View {
  let tint: Color
  var size: CGFloat = 8

  var body: some View {
    Circle()
      .fill(tint)
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}
