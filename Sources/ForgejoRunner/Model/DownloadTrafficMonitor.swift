import Foundation

// reports the bytes tart received every few seconds until its task is cancelled.
@MainActor
struct DownloadTrafficMonitor {
  let commands: CommandExecuting

  func run(onUpdate: (Int64) -> Void) async {
    let request = ProcessNetworkUsage.request(processName: "tart")
    while !Task.isCancelled {
      if let result = try? await commands.run(request, timeout: .seconds(20), outputHandler: nil),
        let bytes = ProcessNetworkUsage.bytesIn(in: result.outputString, processName: "tart")
      {
        onUpdate(bytes)
      } else {
        try? await Task.sleep(for: .seconds(5))
      }
    }
  }
}
