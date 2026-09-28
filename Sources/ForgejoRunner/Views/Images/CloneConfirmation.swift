import SwiftUI

enum CloneConfirmation: Identifiable {
  case discardActiveDownload
  case discardPausedDownload

  var id: Self { self }

  var title: String {
    switch self {
    case .discardActiveDownload: "Cancel the image clone?"
    case .discardPausedDownload: "Discard the paused download?"
    }
  }
}
