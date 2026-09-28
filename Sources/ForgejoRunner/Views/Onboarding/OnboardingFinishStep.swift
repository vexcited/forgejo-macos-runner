import SwiftUI

struct OnboardingFinishStep: View {
  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 72, weight: .regular))
        .foregroundStyle(.green)
        .symbolRenderingMode(.hierarchical)
      Text("Ready!")
        .font(.largeTitle.weight(.bold))
      Text("Start Forgejo Runner and it waits for jobs from your connections.")
        .font(.title3)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
