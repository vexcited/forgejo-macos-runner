import AppKit
import SwiftUI

// a shell command the user runs themselves, selectable and one click to copy.
struct CommandText: View {
  let command: String
  @State private var didCopy = false

  var body: some View {
    HStack(spacing: 8) {
      Text(command)
        .font(.callout.monospaced())
        .textSelection(.enabled)
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        didCopy = true
      } label: {
        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
          .frame(width: 14)
      }
      .buttonStyle(.borderless)
      .help("Copy")
      .accessibilityLabel("Copy command")
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    .task(id: didCopy) {
      guard didCopy else { return }
      try? await Task.sleep(for: .seconds(1.5))
      didCopy = false
    }
  }
}
