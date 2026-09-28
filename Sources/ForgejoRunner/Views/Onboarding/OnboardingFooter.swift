import SwiftUI

struct OnboardingFooter: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(OnboardingImageChoice.self) private var imageChoice
  let step: OnboardingStep
  let onMove: (OnboardingStep) -> Void
  @State private var isConfirmingCancel = false

  var body: some View {
    HStack(spacing: 10) {
      if let previous = step.previous {
        if isSettingUpImage {
          Button(model.isInterruptingClone ? "Cancelling..." : "Cancel") {
            isConfirmingCancel = true
          }
          .glassButtonStyle()
          .disabled(model.isInterruptingClone)
        } else {
          Button("Back") { goBack(to: previous) }
            .glassButtonStyle()
        }
      }
      Spacer()
      if step == .finish {
        Button("Not Now") { finish(startingController: false) }
          .glassButtonStyle()
        Button("Start Forgejo Runner") { finish(startingController: true) }
          .glassButtonStyle(prominent: true)
          .keyboardShortcut(.defaultAction)
      } else if step == .image, imageChoice.phase(in: model) == .picking {
        Button(imageChoice.actionTitle(in: model)) { startImage() }
          .glassButtonStyle(prominent: true)
          .keyboardShortcut(.defaultAction)
          .disabled(imageChoice.source.isEmpty || model.isImageOperationRunning)
          .transition(.blurFade)
      } else {
        let isComplete = step.isComplete(in: model)
        if !isComplete, !step.blockingHint.isEmpty {
          Text(step.blockingHint)
            .font(.callout)
            .foregroundStyle(.secondary)
            .transition(.blurFade)
        }
        Button("Continue") {
          if let next = step.next { onMove(next) }
        }
        .glassButtonStyle(prominent: true)
        .keyboardShortcut(.defaultAction)
        .disabled(!isComplete)
      }
    }
    .animation(.smooth(duration: 0.4), value: step.isComplete(in: model))
    .animation(.smooth(duration: 0.4), value: imageChoice.phase(in: model))
    .controlSize(.large)
    .padding(.horizontal, 22)
    .padding(.vertical, 18)
    .alert(cancelTitle, isPresented: $isConfirmingCancel) {
      Button("Cancel and Delete", role: .destructive) {
        Task { await model.cancelImageSetup() }
      }
      Button("Keep Going", role: .cancel) {}
    } message: {
      Text("Everything downloaded so far will be deleted.")
    }
  }

  // on a ready golden image, back opens the image list instead of the previous step.
  private func goBack(to previous: OnboardingStep) {
    guard step == .image else { return onMove(previous) }
    if imageChoice.phase(in: model) == .ready {
      imageChoice.chooseAnother()
    } else {
      onMove(previous)
    }
  }

  // using an image that is already set up goes straight to the next step.
  private func startImage() {
    let usesReadyImage = imageChoice.isReadyToUse(in: model)
    Task {
      await imageChoice.start(in: model)
      if usesReadyImage, model.isGoldenImageReady, let next = step.next {
        onMove(next)
      }
    }
  }

  private var isSettingUpImage: Bool {
    guard step == .image else { return false }
    let phase = imageChoice.phase(in: model)
    return phase == .downloading || phase == .settingUp
  }

  private var cancelTitle: String {
    model.activeClone != nil ? "Cancel the download?" : "Stop setting up the image?"
  }

  private func finish(startingController: Bool) {
    Task {
      await model.finishOnboarding(startingController: startingController)
      model.showMainWindow(using: openWindow)
      dismissWindow(id: "onboarding")
    }
  }
}
