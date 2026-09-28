import SwiftUI

// content fades and blurs in and out instead of sliding.
struct BlurFade: Transition {
  func body(content: Content, phase: TransitionPhase) -> some View {
    content
      .opacity(phase.isIdentity ? 1 : 0)
      .blur(radius: phase.isIdentity ? 0 : 10)
      .scaleEffect(phase.isIdentity ? 1 : 0.98)
  }
}

extension Transition where Self == BlurFade {
  static var blurFade: BlurFade { BlurFade() }
}
