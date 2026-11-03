import Foundation

// a registry tag such as latest, 27.2, 26.1.1, 26.1-beta-2 or 26-rc, ordered newest first.
nonisolated struct ImageTag: Equatable, Hashable, Sendable {
  let name: String
  private let numbers: [Int]
  // releases rank above release candidates, which rank above betas.
  private let stage: Int
  private let stageNumber: Int

  init(_ name: String) {
    self.name = name
    let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
    numbers = parts.first?.split(separator: ".").compactMap { Int($0) } ?? []
    let suffix = parts.count > 1 ? parts[1] : ""
    if suffix.isEmpty {
      stage = 2
    } else if suffix.hasPrefix("rc") {
      stage = 1
    } else {
      stage = 0
    }
    stageNumber = suffix.split(separator: "-").last.flatMap { Int($0) } ?? 0
  }

  var isLatest: Bool {
    name == "latest"
  }

  var isVersion: Bool {
    !numbers.isEmpty
  }

  var isPrerelease: Bool {
    isVersion && stage < 2
  }

  // latest first, then versions from newest to oldest, then anything else by name.
  static func sorted(_ tags: [String]) -> [ImageTag] {
    tags.map(ImageTag.init).sorted { lhs, rhs in
      if lhs.isLatest != rhs.isLatest { return lhs.isLatest }
      if lhs.isVersion != rhs.isVersion { return lhs.isVersion }
      guard lhs.isVersion else { return lhs.name < rhs.name }
      for index in 0..<max(lhs.numbers.count, rhs.numbers.count) {
        let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
        let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
        if left != right { return left > right }
      }
      if lhs.stage != rhs.stage { return lhs.stage > rhs.stage }
      return lhs.stageNumber > rhs.stageNumber
    }
  }
}
