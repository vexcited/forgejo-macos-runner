import Foundation

// bytes a process received so far, read from nettop. tart only prints whole
// percents, which on a large image means minutes between updates.
nonisolated enum ProcessNetworkUsage {
  // nettop waits about five seconds for its one sample.
  static func request(processName: String) -> CommandRequest {
    CommandRequest(
      executableURL: URL(filePath: "/usr/bin/nettop"),
      arguments: ["-p", processName, "-x", "-P", "-J", "bytes_in", "-L", "1"],
      outputLimitBytes: 16_384,
      isLogged: false
    )
  }

  // sums lines such as 17:08:00.559032,tart.11963,56001853, for the process.
  static func bytesIn(in output: String, processName: String) -> Int64? {
    var total: Int64?
    for line in output.split(whereSeparator: \.isNewline) {
      let fields = line.split(separator: ",", omittingEmptySubsequences: false)
      guard fields.count >= 3, fields[1].hasPrefix("\(processName)."),
        let bytes = Int64(fields[2])
      else { continue }
      total = (total ?? 0) + bytes
    }
    return total
  }
}
