import Foundation

enum ProcessRunner {
  static func stream(
    _ path: String, _ arguments: [String], environment: [String: String],
    workingDirectory: String? = nil
  ) throws {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    process.environment = environment
    if let workingDirectory { process.currentDirectoryURL = URL(filePath: workingDirectory) }
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    do {
      try process.run()
    } catch {
      throw ProvisionFailure(message: "could not run \(path): \(error).", code: 1)
    }
    currentChild = process.processIdentifier
    process.waitUntilExit()
    currentChild = 0
    if caughtSignal != 0 {
      throw ProvisionFailure(message: "", code: 128 + caughtSignal)
    }
    guard process.terminationStatus == 0 else {
      let name = URL(filePath: path).lastPathComponent
      throw ProvisionFailure(
        message: "\(name) failed with status \(process.terminationStatus).", code: 1)
    }
  }

  static func capture(
    _ path: String, _ arguments: [String], environment: [String: String],
    workingDirectory: String? = nil
  ) -> (status: Int32, output: String)? {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    process.environment = environment
    if let workingDirectory { process.currentDirectoryURL = URL(filePath: workingDirectory) }
    process.standardInput = FileHandle.nullDevice
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
