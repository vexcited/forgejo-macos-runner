import SwiftUI

struct PausedClonePanel: View {
  let clone: PausedClone
  let isBusy: Bool
  let onResume: () -> Void
  let onDiscard: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Clone paused: \(clone.name)")
            .font(.headline)
          Text(clone.source)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        Spacer()
        Button("Resume", systemImage: "play.fill", action: onResume)
          .buttonStyle(.borderedProminent)
          .disabled(isBusy)
        Button("Discard", systemImage: "trash", action: onDiscard)
          .disabled(isBusy)
      }
      ProgressView(value: clone.hasPartialDownload ? clone.fraction ?? 0 : 0)
        .progressViewStyle(.linear)
      HStack(alignment: .firstTextBaseline) {
        Text(summary)
          .font(.callout)
        Spacer()
        Text("Paused \(clone.pausedAt, style: .relative) ago")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .background(.bar)
  }

  private var summary: String {
    guard clone.hasPartialDownload else {
      return "No disk data was kept. Resume starts the download again."
    }
    if let fraction = clone.fraction, let total = clone.compressedDiskBytes {
      let percent = Int((fraction * 100).rounded())
      return
        "\(percent)% of \(CloneProgressPanel.bytes(total)) is kept on disk. Resume continues from there."
    }
    return "The partial download is kept on disk. Resume continues from there."
  }
}
