import Foundation

enum Console {
  static func log(_ message: String) {
    FileHandle.standardError.write(Data("[golden guest] \(message)\n".utf8))
  }

  static func error(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
  }
}
