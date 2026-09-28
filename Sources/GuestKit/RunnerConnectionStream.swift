import Foundation

public enum RunnerConnectionStream {
  public static func decode(_ input: String) throws -> GuestAssignment {
    var lines = input.components(separatedBy: "\n")
    if lines.last == "" {
      lines.removeLast()
    }

    var cursor = 0
    func read(_ description: String) throws -> String {
      guard cursor < lines.count else {
        throw RunnerStreamError("missing \(description).")
      }
      defer { cursor += 1 }
      return lines[cursor]
    }

    guard try read("stream version") == "FJMR2" else {
      throw RunnerStreamError("unsupported stream version.")
    }

    let name = try read("connection name")
    guard name.wholeMatch(of: #/[A-Za-z0-9][A-Za-z0-9._\-]{0,39}/#) != nil else {
      throw RunnerStreamError("the connection has an invalid name.")
    }

    let url = try read("connection url")
    guard isValidURL(url) else {
      throw RunnerStreamError("the connection has an invalid forgejo url.")
    }

    let uuid = try read("connection uuid")
    guard
      uuid.wholeMatch(
        of: #/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/#)
        != nil
    else {
      throw RunnerStreamError("the connection has an invalid runner uuid.")
    }

    let labelCountField = try read("label count")
    guard let labelCount = parseCount(labelCountField), labelCount >= 1, labelCount <= 128 else {
      throw RunnerStreamError("the label count must be between 1 and 128.")
    }
    var labels: [String] = []
    var seenLabels: Set<String> = []
    for labelIndex in 1...labelCount {
      let label = try read("label \(labelIndex)")
      guard label.wholeMatch(of: #/[A-Za-z0-9][A-Za-z0-9._\-]*:host/#) != nil else {
        throw RunnerStreamError("the connection has an invalid runner label.")
      }
      guard seenLabels.insert(label).inserted else {
        throw RunnerStreamError("the connection repeats a runner label.")
      }
      labels.append(label)
    }

    let proxyURL = try read("broker proxy url")
    guard isValidProxyURL(proxyURL) else {
      throw RunnerStreamError("the broker proxy url is invalid.")
    }

    guard cursor >= lines.count else {
      throw RunnerStreamError("unexpected trailing data.")
    }
    return GuestAssignment(name: name, url: url, uuid: uuid, labels: labels, proxyURL: proxyURL)
  }

  private static func parseCount(_ value: String) -> Int? {
    guard !value.isEmpty, value.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
    return Int(value)
  }

  private static func isValidURL(_ value: String) -> Bool {
    guard value.hasPrefix("https://") else { return false }
    let forbidden: Set<Character> = [" ", "\t", "\r", "\n", "?", "#", "@"]
    return !value.contains(where: { forbidden.contains($0) })
  }

  // only a plain http proxy on an ipv4 address with an alphanumeric credential.
  private static func isValidProxyURL(_ value: String) -> Bool {
    value.wholeMatch(
      of: #/http://[A-Za-z0-9]{1,64}:[A-Za-z0-9]{16,128}@\d{1,3}(\.\d{1,3}){3}:\d{1,5}/#) != nil
  }
}
