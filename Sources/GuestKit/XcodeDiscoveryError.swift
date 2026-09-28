import Foundation

public enum XcodeDiscoveryError: Error, Equatable, CustomStringConvertible {
  case requestedNotInApplications(String)
  case requestedNotUsable(String)
  case noneFound(String)
  case multipleUnselected([String])

  public var exitCode: Int32 {
    switch self {
    case .requestedNotInApplications: 64
    default: 1
    }
  }

  public var description: String {
    switch self {
    case .requestedNotInApplications(let directory):
      "requested xcode must be an Xcode application in \(directory)."
    case .requestedNotUsable(let path):
      "requested xcode is not usable: \(path)"
    case .noneFound(let directory):
      "no usable Xcode application was found in \(directory)."
    case .multipleUnselected(let candidates):
      "multiple xcode applications were found and none is selected:\n"
        + candidates.map { "  \($0)" }.joined(separator: "\n")
        + "\nselect one with xcode-select or pass an Xcode path in Settings."
    }
  }
}
