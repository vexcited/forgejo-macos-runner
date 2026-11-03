import Darwin
import Foundation

nonisolated enum ClonedFileSize {
  // the bytes of an apfs clone that it does not share with the file it was cloned from.
  // du and finder count a clone at its full size even when it shares almost everything.
  static func privateBytes(of url: URL) -> Int64? {
    var attributes = attrlist()
    attributes.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
    attributes.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
    attributes.forkattr = attrgroup_t(ATTR_CMNEXT_PRIVATESIZE)
    // the length, the returned attributes, then the private size.
    let size = MemoryLayout<UInt32>.size + MemoryLayout<attribute_set_t>.size
      + MemoryLayout<off_t>.size
    var buffer = [UInt8](repeating: 0, count: size)
    let options = UInt32(FSOPT_ATTR_CMN_EXTENDED)
    let status = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return getattrlist(path, &attributes, &buffer, buffer.count, options)
    }
    guard status == 0 else { return nil }
    let returned = buffer.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: MemoryLayout<UInt32>.size, as: attribute_set_t.self)
    }
    guard returned.forkattr & attrgroup_t(ATTR_CMNEXT_PRIVATESIZE) != 0 else { return nil }
    return buffer.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: size - MemoryLayout<off_t>.size, as: off_t.self)
    }
  }
}
