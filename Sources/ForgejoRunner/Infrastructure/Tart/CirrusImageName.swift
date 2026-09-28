import Foundation

// reads a cirrus labs package name such as macos-golden-gate-xcode.
nonisolated struct CirrusImageName: Equatable, Sendable {
  let release: MacOSRelease?
  let hasXcode: Bool

  init(packageName: String) {
    let slug = packageName.hasPrefix("macos-") ? String(packageName.dropFirst(6)) : packageName
    release = MacOSRelease.allCases.first { slug.hasPrefix($0.rawValue + "-") }
    hasXcode = slug.hasSuffix("-xcode")
  }

  // accepts a source such as ghcr.io/cirruslabs/macos-tahoe-xcode:latest.
  init(source: String) {
    let last = source.split(separator: "/").last.map(String.init) ?? source
    self.init(packageName: String(last.prefix { $0 != ":" && $0 != "@" }))
  }

  var title: String {
    release?.name ?? "Runner"
  }

  var detail: String {
    let version = release.map { "macOS \($0.version)" } ?? "Runner image"
    return hasXcode ? "\(version) with Xcode" : version
  }
}
