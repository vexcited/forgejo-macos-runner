import Foundation

nonisolated struct WorkerStatus: Identifiable, Equatable, Sendable {
  let connectionName: String
  var phase: WorkerPhase
  var vmName: String?
  var detail: String?
  var updatedAt: Date

  var id: String {
    connectionName
  }
}
