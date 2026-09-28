import SwiftUI

extension View {
  func card(padding: CGFloat = 16) -> some View {
    modifier(CardModifier(padding: padding))
  }
}
