import AppKit
import SwiftUI

// the release icon, with xcode's icon on top when the image includes it.
struct MacOSReleaseBadge: View {
  let image: CirrusImageName
  var size: CGFloat = 40
  // list rows keep room for the xcode icon so their text lines up.
  var reservesXcodeSpace = true

  var body: some View {
    releaseIcon
      .frame(width: size, height: size)
      .overlay(alignment: .bottomTrailing) {
        if image.hasXcode {
          Image(nsImage: Self.xcodeIcon)
            .resizable()
            .frame(width: size * 0.55, height: size * 0.55)
            .offset(x: size * 0.18, y: size * 0.14)
            .help("Comes with Xcode")
        }
      }
      .padding(.trailing, reservesXcodeSpace ? size * 0.18 : 0)
      .accessibilityLabel(image.detail)
  }

  @ViewBuilder
  private var releaseIcon: some View {
    if let release = image.release {
      Image(release.assetName)
        .resizable()
        .interpolation(.high)
    } else {
      Image(systemName: "apple.logo")
        .font(.system(size: size * 0.5))
        .foregroundStyle(.secondary)
    }
  }

  // the installed xcode's icon, or a hammer when xcode is not installed.
  private static let xcodeIcon: NSImage = {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
      return NSWorkspace.shared.icon(forFile: url.path)
    }
    return NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: nil) ?? NSImage()
  }()
}
