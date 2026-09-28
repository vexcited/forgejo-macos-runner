import Foundation

nonisolated enum VMName {
  static let controllerPrefix = "fjmr-"

  static func make(prefix: String, connectionName: String) -> String {
    let reservedPrefix = VMName.prefix(prefix)
    let safeConnection = sanitize(connectionName)
    let unique = UUID().uuidString
      .lowercased()
      .replacingOccurrences(of: "-", with: "")
      .prefix(12)
    let suffix = "-\(unique)"
    let available = max(1, 63 - reservedPrefix.count - suffix.count)
    let connection = String(safeConnection.prefix(available))
    return "\(reservedPrefix)\(connection)\(suffix)"
  }

  static func prefix(_ prefix: String) -> String {
    "\(controllerPrefix)\(sanitize(prefix).prefix(20))-"
  }

  private static func sanitize(_ value: String) -> String {
    let lowered = value.lowercased()
    let mapped = lowered.map { character in
      character.isLetter || character.isNumber ? character : "-"
    }
    let collapsed = String(mapped)
      .replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return collapsed.isEmpty ? "runner" : collapsed
  }
}
