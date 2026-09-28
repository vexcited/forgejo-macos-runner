import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel()
  private var terminationTask: Task<Void, Never>?
  private var signalSources: [DispatchSourceSignal] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    installSignalHandler(for: SIGINT)
    installSignalHandler(for: SIGTERM)

    Task { await model.start() }
    if model.preferences.keepRunningInBackground, launchedAsLoginItem {
      DispatchQueue.main.async {
        for window in NSApp.windows where window.isVisible && window.canBecomeMain {
          window.close()
        }
      }
    }
  }

  private var launchedAsLoginItem: Bool {
    guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
    return event.eventID == kAEOpenApplication
      && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        == keyAELaunchedAsLogInItem
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard terminationTask == nil else { return .terminateLater }
    terminationTask = Task {
      await model.shutdown()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }

  private func installSignalHandler(for signalValue: Int32) {
    signal(signalValue, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: signalValue, queue: .main)
    source.setEventHandler { [weak self] in
      Task { @MainActor in
        self?.terminate(after: signalValue)
      }
    }
    source.resume()
    signalSources.append(source)
  }

  private func terminate(after signalValue: Int32) {
    guard terminationTask == nil else {
      _exit(128 + signalValue)
    }
    terminationTask = Task { [weak self] in
      await self?.model.shutdown()
      _exit(128 + signalValue)
    }
  }
}
