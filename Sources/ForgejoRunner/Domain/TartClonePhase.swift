import Foundation

nonisolated enum TartClonePhase: Equatable, Sendable {
  case starting
  case pullingManifest
  case pullingDisk
  case pullingNVRAM
}
