import Foundation

nonisolated struct TartCloneRequest: Equatable, Sendable {
  let source: String
  let name: String

  var remoteName: TartRemoteName? {
    TartRemoteName(source)
  }

  var isRemote: Bool {
    remoteName != nil
  }
}
