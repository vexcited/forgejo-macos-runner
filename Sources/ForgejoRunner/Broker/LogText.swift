import Foundation

// text from the vm, made safe to show in the activity log.
nonisolated enum LogText {
  static func printable(_ text: String, limit: Int) -> String {
    String(
      String.UnicodeScalarView(
        text.unicodeScalars.prefix(limit).map {
          $0.value < 0x20 || (0x7f...0x9f).contains($0.value)
            || $0.properties.generalCategory == .format ? " " : $0
        }))
  }
}
