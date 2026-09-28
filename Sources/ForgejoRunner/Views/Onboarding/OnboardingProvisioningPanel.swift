import SwiftUI

struct OnboardingProvisioningPanel: View {
  @Environment(AppModel.self) private var model
  @State private var showsDetails = false

  var body: some View {
    VStack(spacing: 22) {
      if !showsDetails {
        Spacer()
      }
      VStack(spacing: 4) {
        Text("Step 2 of 2")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Setting up \(model.preferences.selectedImage)")
          .font(.title3.weight(.semibold))
      }
      VStack(spacing: 8) {
        ProgressView()
          .progressViewStyle(.linear)
          .controlSize(.large)
        Text("Installing the tools your jobs need. This can take 15 minutes or more.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Button(showsDetails ? "Hide Details" : "Show Details") {
        withAnimation(.smooth(duration: 0.4)) { showsDetails.toggle() }
      }
      .buttonStyle(.link)
      if showsDetails {
        ConsoleView(output: model.operationOutput, maxHeight: .infinity)
          .transition(.blurFade)
      } else {
        Spacer()
        Spacer()
      }
    }
    .padding(.horizontal, 48)
    .padding(.bottom, showsDetails ? 12 : 0)
  }
}
