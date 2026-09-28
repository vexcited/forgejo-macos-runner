import SwiftUI

// the forgejo mark scaled to fit, centered, keeping its proportions.
nonisolated struct ForgejoMarkShape: Shape {
  func path(in rect: CGRect) -> Path {
    let artwork = ForgejoMark.size
    let scale = min(rect.width / artwork.width, rect.height / artwork.height)
    let transform = CGAffineTransform(
      translationX: rect.midX - artwork.width * scale / 2,
      y: rect.midY - artwork.height * scale / 2
    ).scaledBy(x: scale, y: scale)
    return Path(ForgejoMark.path().cgPath).applying(transform)
  }
}
