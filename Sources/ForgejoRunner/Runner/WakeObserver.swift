import AppKit
import Foundation

// calls back on the main actor each time the mac wakes, while registered.
@MainActor
final class WakeObserver {
  private var observer: NSObjectProtocol?

  func register(onWake: @escaping @MainActor @Sendable () -> Void) {
    guard observer == nil else { return }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { _ in
      Task { @MainActor in
        onWake()
      }
    }
  }

  func remove() {
    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observer = nil
  }
}
