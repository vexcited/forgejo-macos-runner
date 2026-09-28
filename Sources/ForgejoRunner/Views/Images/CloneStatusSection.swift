import SwiftUI

struct CloneStatusSection: View {
  @Environment(AppModel.self) private var model
  let onConfirm: (CloneConfirmation) -> Void

  var body: some View {
    if let request = model.activeClone, let progress = model.cloneProgress {
      Divider()
      CloneProgressPanel(
        request: request,
        progress: progress,
        isInterrupting: model.isInterruptingClone,
        onPause: { Task { await model.pauseClone() } },
        onCancel: {
          if request.isRemote {
            onConfirm(.discardActiveDownload)
          } else {
            Task { await model.cancelClone() }
          }
        }
      )
    } else if let paused = model.pausedClone {
      Divider()
      PausedClonePanel(
        clone: paused,
        isBusy: model.isImageOperationRunning || model.coordinator.isRunning,
        onResume: { Task { await model.resumePausedClone() } },
        onDiscard: { onConfirm(.discardPausedDownload) }
      )
    }
  }
}
