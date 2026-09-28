import SwiftUI

// a small centered window that walks through setup before the app opens.
struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @State private var step = OnboardingStep.welcome
  @State private var imageChoice = OnboardingImageChoice()

  var body: some View {
    VStack(spacing: 0) {
      OnboardingProgressDots(current: step) { go(to: $0) }
        .padding(.top, 18)
      ZStack(alignment: .top) {
        Group {
          switch step {
          case .welcome: OnboardingWelcomeStep()
          case .sandbox: OnboardingSandboxStep()
          case .image: OnboardingImageStep()
          case .connections: OnboardingConnectionsStep()
          case .preferences: OnboardingPreferencesStep()
          case .finish: OnboardingFinishStep()
          }
        }
        .id(step)
        .transition(.blurFade)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      OnboardingFooter(step: step) { go(to: $0) }
    }
    .environment(imageChoice)
    .frame(width: 640, height: 620)
    .containerBackground(.regularMaterial, for: .window)
    .onAppear { model.mainWindowDidOpen() }
    .onDisappear { model.mainWindowDidClose() }
    // an image cloned during setup is always meant to become the golden image.
    .onChange(of: model.pendingGoldenPrompt?.id) {
      guard model.pendingGoldenPrompt != nil else { return }
      Task { await model.resolveGoldenPrompt(use: true) }
    }
  }

  private func go(to target: OnboardingStep) {
    withAnimation(.smooth(duration: 0.4)) { step = target }
  }
}
