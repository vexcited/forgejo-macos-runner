import Foundation

// a redirect would re-send the runner token, or point a lookup somewhere else, so the
// 3xx answer is returned as is and treated as a failure.
final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
  static let shared = NoRedirects()

  nonisolated func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
