import Foundation

// Presented after a clone to ask whether the new image should become the golden
// runner image. `useByDefault` is on only when no golden image is set yet.
nonisolated struct GoldenImagePrompt: Identifiable, Equatable, Sendable {
  let id = UUID()
  let imageName: String
  let useByDefault: Bool
}
