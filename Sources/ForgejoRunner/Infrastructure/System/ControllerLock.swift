import Darwin
import Foundation

@MainActor
final class ControllerLock {
  private let fileURL: URL
  private var fileDescriptor: Int32 = -1

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func acquire() throws {
    guard fileDescriptor == -1 else { return }
    let parent = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: parent,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: parent.path
    )
    let descriptor = fileURL.path.withCString {
      Darwin.open($0, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    }
    guard descriptor >= 0 else {
      throw ControllerLockError.cannotOpen
    }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      Darwin.close(descriptor)
      throw ControllerLockError.alreadyRunning
    }
    guard fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
      flock(descriptor, LOCK_UN)
      Darwin.close(descriptor)
      throw ControllerLockError.cannotOpen
    }
    fileDescriptor = descriptor
  }

  func release() {
    guard fileDescriptor >= 0 else { return }
    flock(fileDescriptor, LOCK_UN)
    Darwin.close(fileDescriptor)
    fileDescriptor = -1
  }

  deinit {
    if fileDescriptor >= 0 {
      Darwin.close(fileDescriptor)
    }
  }
}
