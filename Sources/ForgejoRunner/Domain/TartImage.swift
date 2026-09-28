import Foundation

nonisolated struct TartImage: Decodable, Identifiable, Equatable, Sendable {
  let source: String
  let name: String
  let diskSizeGB: Int
  let allocatedSizeGB: Int
  let accessed: String
  let state: String
  let isRunning: Bool

  var id: String {
    name
  }

  private enum CodingKeys: String, CodingKey {
    case source = "Source"
    case name = "Name"
    case diskSizeGB = "Disk"
    case allocatedSizeGB = "Size"
    case accessed = "Accessed"
    case state = "State"
    case isRunning = "Running"
  }

  static func decodeList(_ data: Data) throws -> [TartImage] {
    try JSONDecoder().decode([TartImage].self, from: data)
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
}
