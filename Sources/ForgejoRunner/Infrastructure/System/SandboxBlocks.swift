import Foundation

nonisolated struct SandboxBlocks: Equatable, Sendable {
  let networks: Set<String>
  let routerAddressKnown: Bool
}
