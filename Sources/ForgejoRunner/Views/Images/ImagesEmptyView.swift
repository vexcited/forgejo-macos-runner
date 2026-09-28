import SwiftUI

struct ImagesEmptyView: View {
  let canStartClone: Bool
  let onClone: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("No images in the app's Tart home", systemImage: "shippingbox")
    } description: {
      Text(
        "Clone a Cirrus image here. You can then use it as the golden runner image, which provisions it automatically."
      )
    } actions: {
      Button("Clone Image", action: onClone)
        .disabled(!canStartClone)
    }
  }
}
