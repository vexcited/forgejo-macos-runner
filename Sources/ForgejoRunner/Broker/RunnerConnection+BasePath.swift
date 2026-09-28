import Foundation

extension RunnerConnection {
  // the path prefix of the instance url without a trailing slash.
  nonisolated var basePath: String {
    var path = url.path(percentEncoded: true)
    while path.hasSuffix("/") {
      path.removeLast()
    }
    return path
  }
}
