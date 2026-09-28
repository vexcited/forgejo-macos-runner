import Foundation

// the vm controls these strings, so they are cleaned and rate limited before they
// reach the activity log.
@MainActor
final class BrokerRefusalLog {
  private static let maximumLoggedRefusals = 20

  private let logHandler: @MainActor @Sendable (String) -> Void
  private var loggedRefusals = 0

  init(logHandler: @escaping @MainActor @Sendable (String) -> Void) {
    self.logHandler = logHandler
  }

  func log(_ message: String) {
    guard loggedRefusals < Self.maximumLoggedRefusals else { return }
    loggedRefusals += 1
    let printable = LogText.printable(message, limit: 300)
    logHandler(
      loggedRefusals == Self.maximumLoggedRefusals
        ? "\(printable) Further refusals in this session are not logged." : printable)
  }
}
