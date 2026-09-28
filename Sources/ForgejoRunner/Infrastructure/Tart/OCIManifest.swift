import Foundation

// the parts of a tart image manifest that tell how large the image gets on disk.
nonisolated struct OCIManifest: Decodable, Sendable {
  nonisolated struct Layer: Decodable, Sendable {
    let size: Int64
    let annotations: [String: String]?
  }

  let layers: [Layer]
  let annotations: [String: String]?

  // the unpacked disk plus the small config and nvram layers.
  var unpackedBytes: Int64 {
    let diskKey = "org.cirruslabs.tart.uncompressed-disk-size"
    let layerKey = "org.cirruslabs.tart.uncompressed-size"
    let diskLayers = layers.filter { $0.annotations?[layerKey] != nil }
    let disk =
      annotations?[diskKey].flatMap { Int64($0) }
      ?? diskLayers.reduce(0) { $0 + (Int64($1.annotations?[layerKey] ?? "") ?? 0) }
    let others = layers.filter { $0.annotations?[layerKey] == nil }.reduce(0) { $0 + $1.size }
    return disk + others
  }
}
