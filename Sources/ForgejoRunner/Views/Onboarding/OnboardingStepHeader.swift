import SwiftUI

struct OnboardingStepHeader: View {
  let symbol: String
  var tint: Color = .accentColor
  let title: String
  let subtitle: String
  private var icon: AnyView?

  init(step: OnboardingStep) {
    self.init(symbol: step.symbol, title: step.title, subtitle: step.subtitle)
  }

  init(symbol: String, tint: Color = .accentColor, title: String, subtitle: String) {
    self.symbol = symbol
    self.tint = tint
    self.title = title
    self.subtitle = subtitle
  }

  init(title: String, subtitle: String, @ViewBuilder icon: () -> some View) {
    self.init(symbol: "", title: title, subtitle: subtitle)
    self.icon = AnyView(icon())
  }

  var body: some View {
    VStack(spacing: 8) {
      if let icon {
        icon
          .padding(.bottom, 4)
      } else {
        Image(systemName: symbol)
          .font(.system(size: 30, weight: .regular))
          .foregroundStyle(tint)
          .frame(height: 36)
      }
      Text(title)
        .font(.title2.weight(.semibold))
      Text(subtitle)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: 440)
    .padding(.top, 30)
    .padding(.bottom, 6)
  }
}
