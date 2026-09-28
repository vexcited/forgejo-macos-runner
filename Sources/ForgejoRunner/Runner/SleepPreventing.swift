import Foundation

@MainActor
protocol SleepPreventing: AnyObject {
  func run() async throws
}
