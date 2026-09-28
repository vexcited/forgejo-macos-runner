import Foundation

nonisolated struct CommandLogEntry: Identifiable, Equatable, Sendable {
  let id: UUID
  let date: Date
  let line: String
}
