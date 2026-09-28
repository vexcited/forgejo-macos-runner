import SwiftUI

struct OnboardingProgressDots: View {
  @Environment(AppModel.self) private var model
  let current: OnboardingStep
  let onSelect: (OnboardingStep) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(OnboardingStep.allCases) { step in
        Button {
          onSelect(step)
        } label: {
          Capsule()
            .fill(color(for: step))
            .frame(width: step == current ? 22 : 7, height: 7)
            .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .disabled(!step.isReachable(in: model))
        .help(step.title)
        .accessibilityLabel("Step \(step.rawValue + 1), \(step.title)")
      }
    }
    .animation(.smooth(duration: 0.35), value: current)
  }

  private func color(for step: OnboardingStep) -> Color {
    if step == current { return .accentColor }
    if step.rawValue < current.rawValue { return .accentColor.opacity(0.45) }
    return .secondary.opacity(0.3)
  }
}
