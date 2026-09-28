import Foundation

enum Machine {
  static func isARM64() -> Bool {
    var info = utsname()
    uname(&info)
    let machine = withUnsafePointer(to: &info.machine) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
    }
    return machine == "arm64"
  }
}
