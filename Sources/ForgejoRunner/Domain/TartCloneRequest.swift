import Foundation

nonisolated struct TartCloneRequest: Equatable, Sendable {
  let source: String
  let name: String
  // the local image this download takes the place of once it is complete.
  var replacing: String? = nil

  var remoteName: TartRemoteName? {
    TartRemoteName(source)
  }

  var isRemote: Bool {
    remoteName != nil
  }
}
