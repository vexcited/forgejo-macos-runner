import Darwin
import Foundation

// captures the combined output of a process, keeping only the last limit bytes.
nonisolated enum ProcessOutputReader {
  static func read(
    from handle: FileHandle,
    limit: Int,
    handler: (@MainActor @Sendable (String) -> Void)?
  ) async -> Data {
    var captured = Data()
    var buffer = [UInt8](repeating: 0, count: 65_536)
    while !Task.isCancelled {
      // FileHandle.read(upToCount:) waits for the full count or end of file on a pipe,
      // which would hold every progress line back until the process exits.
      guard let chunk = readAvailable(from: handle.fileDescriptor, into: &buffer) else {
        break
      }
      if let handler {
        await handler(String(decoding: chunk, as: UTF8.self))
      }
      if chunk.count >= limit {
        captured = Data(chunk.suffix(limit))
      } else {
        let overflow = captured.count + chunk.count - limit
        if overflow > 0 {
          captured.removeFirst(overflow)
        }
        captured.append(chunk)
      }
    }
    try? handle.close()
    return captured
  }

  private static func readAvailable(
    from descriptor: Int32,
    into buffer: inout [UInt8]
  ) -> Data? {
    while true {
      let count = buffer.withUnsafeMutableBytes { bytes in
        Darwin.read(descriptor, bytes.baseAddress, bytes.count)
      }
      if count > 0 {
        return Data(buffer[..<count])
      }
      if count < 0, errno == EINTR {
        continue
      }
      return nil
    }
  }
}
