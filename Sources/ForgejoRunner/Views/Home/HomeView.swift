import SwiftUI

// the whole app on one screen: what the runner is doing and the one button that
// changes it. everything else opens as a sheet from the corner.
struct HomeView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    let status = model.controllerStatus
    let detail = HomeStatusDetail(model: model).text

    VStack(spacing: 0) {
      Spacer(minLength: 12)
      StatusRing(status: status)
      VStack(spacing: 6) {
        // each new text replaces the old one with a blur, so a change is noticed.
        ZStack {
          Text(status.title)
            .id(status.title)
            .transition(.blurFade)
        }
        .font(.largeTitle.weight(.semibold))
        .animation(.smooth(duration: 0.4), value: status.title)
        ZStack {
          Text(detail)
            .id(detail)
            .transition(.blurFade)
        }
        .font(.callout)
        .foregroundStyle(status == .failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .frame(maxWidth: 340)
        .animation(.smooth(duration: 0.4), value: detail)
      }
      .padding(.top, 22)
      ControllerButton(fillsWidth: true)
        .controlSize(.extraLarge)
        .glassButtonStyle(prominent: !model.coordinator.isRunning)
        .frame(width: 220)
        .padding(.top, 26)
      Spacer(minLength: 12)
      LatestActivityBar()
    }
    .frame(width: 440, height: 540)
    .toolbar { HomeToolbar(openWindow: openWindow) }
    .toolbar(removing: .title)
    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
  }
}
