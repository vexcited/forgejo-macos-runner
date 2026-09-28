import Foundation

// checks names and sources before they reach the tart command line.
nonisolated enum TartInputValidation {
  static func validateName(_ name: String) throws {
    guard name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$"#, options: .regularExpression) != nil
    else {
      throw TartError.invalidName
    }
  }

  static func normalizedSource(_ source: String) throws -> String {
    let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedSource.isEmpty,
      normalizedSource.utf8.count <= 2_048,
      !normalizedSource.hasPrefix("-"),
      normalizedSource.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
      normalizedSource.rangeOfCharacter(from: .controlCharacters) == nil
    else {
      throw TartError.invalidSource
    }
    return normalizedSource
  }
}
