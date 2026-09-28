import Foundation

nonisolated struct RunnerConnection: Identifiable, Hashable, Sendable, CustomStringConvertible {
  let name: String
  let url: URL
  let uuid: UUID
  let token: RunnerToken
  let labels: [String]

  var id: String {
    name
  }

  // the names workflows target with runs-on, without the host suffix.
  var labelNames: [String] {
    labels.map(Self.labelName(from:))
  }

  var description: String {
    "RunnerConnection(name: \(name), url: \(url.absoluteString), uuid: \(uuid), token: <redacted>, labels: \(labels))"
  }

  // every label runs jobs directly in the disposable vm.
  static let hostLabelSuffix = ":host"

  static func labelName(from label: String) -> String {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasSuffix(hostLabelSuffix)
      ? String(trimmed.dropLast(hostLabelSuffix.count)) : trimmed
  }

  static func isValidLabelName(_ name: String) -> Bool {
    name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil
  }

  static func validated(
    name: String,
    url: String,
    uuid: String,
    token: String,
    labels: [String]
  ) throws -> RunnerConnection {
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      normalizedName.range(
        of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$"#,
        options: .regularExpression
      ) != nil
    else {
      throw ConnectionValidationError.invalidName
    }

    let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedURL.hasPrefix("https://"),
      normalizedURL.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
      normalizedURL.rangeOfCharacter(from: .controlCharacters) == nil,
      !normalizedURL.contains("@"),
      let parsedURL = URL(string: normalizedURL),
      parsedURL.scheme?.lowercased() == "https",
      parsedURL.host?.isEmpty == false,
      parsedURL.user == nil,
      parsedURL.password == nil,
      parsedURL.query == nil,
      parsedURL.fragment == nil
    else {
      throw ConnectionValidationError.invalidURL
    }

    guard let parsedUUID = UUID(uuidString: uuid.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
      throw ConnectionValidationError.invalidUUID
    }

    guard !token.isEmpty,
      token.utf8.count <= 4_096,
      token.rangeOfCharacter(from: .controlCharacters) == nil
    else {
      throw ConnectionValidationError.invalidToken
    }
    // a file: reference from an older version would otherwise pass as a literal token.
    guard !token.hasPrefix("file:") else {
      throw ConnectionValidationError.tokenFileUnsupported
    }
    guard token.utf8.count <= 1_024, token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    else {
      throw ConnectionValidationError.invalidToken
    }

    guard !labels.isEmpty, labels.count <= 128 else {
      throw ConnectionValidationError.invalidLabels
    }
    let names = labels.map(labelName(from:))
    guard Set(names).count == names.count, names.allSatisfy(isValidLabelName) else {
      throw ConnectionValidationError.invalidLabels
    }
    let normalizedLabels = names.map { $0 + hostLabelSuffix }

    return RunnerConnection(
      name: normalizedName,
      url: parsedURL,
      uuid: parsedUUID,
      token: RunnerToken(rawValue: token),
      labels: normalizedLabels
    )
  }
}
