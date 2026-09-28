import Foundation

// the space files in a folder really take on disk, holes in sparse files excluded.
nonisolated enum DirectoryAllocation {
  static func allocatedBytes(in directory: URL) -> Int64 {
    let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
    guard
      let files = FileManager.default.enumerator(
        at: directory, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants])
    else { return 0 }
    var total: Int64 = 0
    for case let file as URL in files {
      guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true
      else { continue }
      total += Int64(values.totalFileAllocatedSize ?? 0)
    }
    return total
  }
}
