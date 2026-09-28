import Foundation
import Network

// Reports whether the Mac currently has a usable network path. The controller uses
// it to avoid spending a VM clone while offline (for example while travelling with no
// signal) and to resume the moment connectivity returns.
@MainActor
@Observable
final class NetworkMonitor {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.vexcited.forgejo.runner.network")
  private var started = false

  // optimistic default so a not-yet-reported path never blocks startup.
  private(set) var isReachable = true
  // called on the main actor after every path update, reachable or not.
  var onChange: (@MainActor () -> Void)?

  func start() {
    guard !started else { return }
    started = true
    monitor.pathUpdateHandler = { [weak self] path in
      let reachable = path.status == .satisfied
      Task { @MainActor in
        self?.isReachable = reachable
        self?.onChange?()
      }
    }
    monitor.start(queue: queue)
  }
}
