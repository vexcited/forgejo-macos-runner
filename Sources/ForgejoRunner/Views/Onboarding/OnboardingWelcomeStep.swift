import AppKit
import SwiftUI

struct OnboardingWelcomeStep: View {
  var body: some View {
    VStack(spacing: 22) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 92, height: 92)
        .accessibilityHidden(true)
      VStack(spacing: 6) {
        Text("Welcome to Forgejo Runner")
          .font(.largeTitle.weight(.semibold))
        Text(
          "Run your Forgejo Actions jobs on this Mac, each one on a fresh macOS that is wiped afterwards."
        )
        .font(.title3)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      }
      .frame(maxWidth: 460)
      VStack(alignment: .leading, spacing: 14) {
        OnboardingFeatureRow(
          symbol: "lock.shield", title: "Isolated",
          detail: "Jobs reach the internet, never this Mac or your network.")
        OnboardingFeatureRow(
          symbol: "key", title: "Tokens stay here",
          detail: "Runner tokens stay with the app, jobs never see them.")
        OnboardingFeatureRow(
          symbol: "arrow.triangle.2.circlepath", title: "Disposable",
          detail: "Every job starts clean and leaves nothing behind.")
      }
      .padding(18)
      .frame(maxWidth: 460, alignment: .leading)
      .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }
    .padding(.top, 24)
    .padding(.horizontal, 32)
  }
}
