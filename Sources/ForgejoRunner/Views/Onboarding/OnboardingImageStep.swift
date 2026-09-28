import SwiftUI

struct OnboardingImageStep: View {
  @Environment(AppModel.self) private var model
  @Environment(OnboardingImageChoice.self) private var choice
  @State private var confirmation: CloneConfirmation?

  var body: some View {
    let phase = choice.phase(in: model)
    ZStack {
      if phase == .ready {
        // the ready image sits in the middle of the step, a little above center.
        readyHeader
          .padding(.bottom, 60)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .transition(.blurFade)
      } else {
        VStack(spacing: 0) {
          OnboardingStepHeader(step: .image)
          ZStack(alignment: .top) {
            Group {
              switch phase {
              case .picking:
                OnboardingImagePicker()
              case .downloading:
                OnboardingDownloadPanel()
              case .settingUp:
                OnboardingProvisioningPanel()
              case .paused, .ready:
                paused
              }
            }
            .id(phase)
            .transition(.blurFade)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .animation(.smooth(duration: 0.4), value: phase)
        }
        .transition(.blurFade)
      }
    }
    .animation(.smooth(duration: 0.4), value: phase == .ready)
    .modifier(CloneConfirmationAlert(confirmation: $confirmation))
  }

  @ViewBuilder
  private var paused: some View {
    if let clone = model.pausedClone {
      VStack {
        Spacer()
        PausedClonePanel(
          clone: clone,
          isBusy: model.isImageOperationRunning,
          onResume: { Task { await model.resumePausedClone() } },
          onDiscard: { confirmation = .discardPausedDownload }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        Spacer()
        Spacer()
      }
      .padding(.horizontal, 30)
    }
  }

  // the header carries the status, like the sandbox step once it is set up.
  private var readyHeader: some View {
    let name = model.preferences.selectedImage
    let image = CirrusImageName(packageName: name)
    let title = image.release == nil ? name : image.title
    let detail = image.release == nil ? "Your own image" : image.detail
    return OnboardingStepHeader(
      title: "\(title) is ready",
      subtitle:
        "\(detail), set up with Forgejo Runner \(model.preferences.runnerVersion). Every job starts from a fresh copy of it."
    ) {
      MacOSReleaseBadge(image: image, size: 72, reservesXcodeSpace: false)
        .overlay(alignment: .topTrailing) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .green)
            .offset(x: 6, y: -6)
        }
    }
  }
}
