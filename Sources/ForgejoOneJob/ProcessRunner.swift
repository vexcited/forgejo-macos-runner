import Foundation

enum ProcessRunner {
  static func capture(_ path: String, _ arguments: [String]) -> (status: Int32, output: String)? {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
      try process.run()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
  }
}
