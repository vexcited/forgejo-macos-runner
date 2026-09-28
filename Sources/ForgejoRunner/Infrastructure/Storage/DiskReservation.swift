import Darwin
import Foundation

// a file whose disk blocks are allocated up front, so the space stays free for a download.
// it runs off the main actor, since allocating tens of gigabytes takes a second or two.
actor DiskReservation {
  private let url: URL
  private var descriptor: Int32 = -1
  private var size: Int64 = 0

  init(url: URL) {
    self.url = url
  }

  func reserve(_ bytes: Int64) throws {
    release()
    descriptor = open(url.path, O_RDWR | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw DiskSpaceError.reservationFailed(errno) }
    var store = fstore_t(
      fst_flags: UInt32(F_ALLOCATEALL), fst_posmode: F_PEOFPOSMODE, fst_offset: 0,
      fst_length: off_t(bytes), fst_bytesalloc: 0)
    guard fcntl(descriptor, F_PREALLOCATE, &store) == 0, ftruncate(descriptor, off_t(bytes)) == 0
    else {
      let code = errno
      release()
      throw DiskSpaceError.reservationFailed(code)
    }
    size = bytes
  }

  // hands space back as the download fills the folder, never takes more.
  func shrink(toCover required: Int64, writtenIn directory: URL) {
    guard descriptor >= 0 else { return }
    let target = max(required - DirectoryAllocation.allocatedBytes(in: directory), 0)
    guard target < size, ftruncate(descriptor, off_t(target)) == 0 else { return }
    size = target
  }

  // closing a file that still holds its preallocated blocks takes apfs about half a
  // second per gigabyte, emptying it first makes the whole release instant.
  func release() {
    guard descriptor >= 0 else { return }
    ftruncate(descriptor, 0)
    close(descriptor)
    descriptor = -1
    size = 0
    unlink(url.path)
  }

  // clears reservations a crash left behind, without holding up launch.
  static func removeLeftovers(of url: URL) {
    let directory = url.deletingLastPathComponent()
    let prefix = url.lastPathComponent
    Task.detached(priority: .utility) {
      let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
      for name in names where name.hasPrefix(prefix) {
        unlink(directory.appending(path: name).path)
      }
    }
  }
}
