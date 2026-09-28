import Foundation

nonisolated struct BrokerForward: Equatable, Sendable {
  let guestPort: UInt16
  let hostSocket: String
}
