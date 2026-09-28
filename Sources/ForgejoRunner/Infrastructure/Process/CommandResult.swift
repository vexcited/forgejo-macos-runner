import Foundation

nonisolated struct CommandResult: Equatable, Sendable {
  let status: Int32
  let output: Data

  var outputString: String {
    String(decoding: output, as: UTF8.self)
  }
}
