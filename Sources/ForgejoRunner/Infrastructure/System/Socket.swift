import Darwin

nonisolated enum Socket {
  // a write to a socket the system has reset, as macOS does while it checks local
  // network access for an app opened from the finder, then fails with EPIPE instead of
  // ending the whole app with SIGPIPE.
  static func disableSIGPIPE(_ socket: Int32) {
    var enabled: Int32 = 1
    setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
  }
}
