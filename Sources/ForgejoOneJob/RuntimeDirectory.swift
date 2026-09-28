import Foundation

struct RuntimeDirectory {
  let path: String

  static func make() -> RuntimeDirectory? {
    let runtimeParent =
      ProcessInfo.processInfo.environment["FORGEJO_RUNTIME_PARENT"] ?? "/private/tmp"
    var template = Array("\(runtimeParent)/forgejo-runner.XXXXXX".utf8CString)
    let created = template.withUnsafeMutableBufferPointer { mkdtemp($0.baseAddress) }
    guard created != nil else { return nil }
    let bytes = template.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return RuntimeDirectory(path: String(decoding: bytes, as: UTF8.self))
  }

  func remove() {
    try? FileManager.default.removeItem(atPath: path)
  }
}
