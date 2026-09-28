import Foundation

// what the golden image step shows at a time.
enum OnboardingImagePhase: Hashable {
  case picking
  case downloading
  case paused
  case settingUp
  case ready
}
