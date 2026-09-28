import Foundation

// holds the free space an image needs for the whole download, and hands it back
// as tart writes the disk.
@MainActor
final class DownloadSpaceReservation {
  // room for tart's metadata on top of the image itself.
  private static let margin: Int64 = 2_000_000_000
  private let paths: AppPaths
  private let reservation: DiskReservation
  private var required: Int64 = 0

  init(paths: AppPaths) {
    self.paths = paths
    reservation = DiskReservation(url: paths.downloadReservationFile)
  }

  // returns false when the size is unknown, then the download runs without a reservation.
  func begin(source: String) async throws -> Bool {
    guard let size = try? await RegistryImageSize.unpackedBytes(source: source) else {
      return false
    }
    required = size + Self.margin
    let written = DirectoryAllocation.allocatedBytes(in: paths.tartTemporaryDirectory)
    let needed = max(required - written, 0)
    // preallocation only takes space that is free now, not space macOS could purge.
    let values = try paths.appSupport.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    let available = Int64(values.volumeAvailableCapacity ?? 0)
    guard needed <= available else {
      throw DiskSpaceError.notEnough(needed: needed, available: available)
    }
    do {
      try await reservation.reserve(needed)
    } catch DiskSpaceError.reservationFailed(ENOSPC) {
      throw DiskSpaceError.notEnough(needed: needed, available: available)
    }
    return true
  }

  func update() {
    let (reservation, required, folder) = (reservation, required, paths.tartTemporaryDirectory)
    Task { await reservation.shrink(toCover: required, writtenIn: folder) }
  }

  func end() async {
    await reservation.release()
  }
}
