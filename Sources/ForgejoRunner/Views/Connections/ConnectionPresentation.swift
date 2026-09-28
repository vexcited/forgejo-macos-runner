import SwiftUI

struct ConnectionPresentation: Identifiable {
  let id = UUID()
  let originalName: String?
  let connection: RunnerConnection?
}
