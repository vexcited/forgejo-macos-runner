import Foundation

nonisolated struct ActivityEntry: Identifiable, Equatable, Sendable {
  let id: UUID
  let date: Date
  let message: String
}
