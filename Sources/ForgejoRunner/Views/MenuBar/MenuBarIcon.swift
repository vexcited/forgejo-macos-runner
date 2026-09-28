import AppKit

// the forgejo mark with a small status badge, drawn as a template image so the menu
// bar tints it like every other item.
enum MenuBarIcon {
  private static let canvas = NSSize(width: 18, height: 16)
  private static var cache: [MenuBarIconStyle: NSImage] = [:]

  static func image(for status: ControllerStatus) -> NSImage {
    let style = MenuBarIconStyle(status)
    if let image = cache[style] { return image }
    let image = NSImage(size: canvas, flipped: true) { _ in
      draw(style)
      return true
    }
    image.isTemplate = true
    cache[style] = image
    return image
  }

  private static func draw(_ style: MenuBarIconStyle) {
    let height: CGFloat = 15
    let scale = height / ForgejoMark.size.height
    let mark = ForgejoMark.path()
    var transform = AffineTransform(translationByX: 2, byY: 0.5)
    transform.scale(scale)
    mark.transform(using: transform)
    NSColor.black.withAlphaComponent(style == .stopped ? 0.45 : 1).setFill()
    mark.fill()

    let badge = NSRect(x: 11.5, y: 9, width: 6.5, height: 6.5)
    switch style {
    case .stopped, .listening:
      break
    case .working:
      NSColor.black.setFill()
      NSBezierPath(ovalIn: badge).fill()
    case .attention:
      NSColor.black.setFill()
      NSBezierPath(ovalIn: badge).fill()
      NSGraphicsContext.current?.compositingOperation = .clear
      NSBezierPath(rect: NSRect(x: badge.midX - 0.6, y: badge.minY + 1.2, width: 1.2, height: 2.6))
        .fill()
      NSBezierPath(ovalIn: NSRect(x: badge.midX - 0.65, y: badge.maxY - 2, width: 1.3, height: 1.3))
        .fill()
      NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
  }
}
