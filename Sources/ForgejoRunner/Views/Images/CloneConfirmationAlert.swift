import SwiftUI

struct CloneConfirmationAlert: ViewModifier {
  @Environment(AppModel.self) private var model
  @Binding var confirmation: CloneConfirmation?

  func body(content: Content) -> some View {
    content
      .alert(
        confirmation?.title ?? "",
        isPresented: isPresented,
        presenting: confirmation
      ) { confirmation in
        switch confirmation {
        case .discardActiveDownload:
          Button("Discard Download", role: .destructive) {
            Task { await model.cancelClone() }
          }
          Button("Keep Downloading", role: .cancel) {}
        case .discardPausedDownload:
          Button("Discard", role: .destructive) {
            model.discardPausedClone()
          }
          Button("Keep", role: .cancel) {}
        }
      } message: { confirmation in
        switch confirmation {
        case .discardActiveDownload:
          Text(
            "Everything downloaded so far will be deleted. Use Pause instead to keep the partial download for later."
          )
        case .discardPausedDownload:
          Text("The partial download kept on disk will be deleted.")
        }
      }
  }

  private var isPresented: Binding<Bool> {
    Binding(
      get: { confirmation != nil },
      set: { if !$0 { confirmation = nil } }
    )
  }
}
