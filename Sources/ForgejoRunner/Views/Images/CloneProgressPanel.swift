import SwiftUI

struct CloneProgressPanel: View {
  let request: TartCloneRequest
  let progress: TartCloneProgress
  let isInterrupting: Bool
  let onPause: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Cloning \(request.name)")
            .font(.headline)
          Text(request.source)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        Spacer()
        if isInterrupting {
          ProgressView()
            .controlSize(.small)
          Text("Stopping...")
            .foregroundStyle(.secondary)
        } else {
          Button("Pause", systemImage: "pause.fill", action: onPause)
            .disabled(!request.isRemote)
            .help(
              request.isRemote
                ? "Keep the partial download so it can be resumed later."
                : "Local clones finish quickly and cannot be paused."
            )
          Button("Cancel", systemImage: "xmark", action: onCancel)
        }
      }
      if let fraction = progress.fraction {
        ProgressView(value: fraction)
          .progressViewStyle(.linear)
          .animation(.default, value: fraction)
      } else {
        ProgressView()
          .progressViewStyle(.linear)
      }
      HStack(alignment: .firstTextBaseline) {
        Text(detail)
          .font(.callout)
        Spacer()
        if let fraction = progress.fraction {
          Text(fraction, format: .percent.precision(.fractionLength(0)))
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      if let status = progress.statusLine {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .textSelection(.enabled)
      }
    }
    .padding(14)
    .background(.bar)
  }

  private var detail: String {
    switch progress.phase {
    case .starting:
      request.isRemote ? "Starting the download..." : "Cloning the local image..."
    case .pullingManifest:
      "Fetching the image manifest..."
    case .pullingDisk:
      if let downloaded = progress.downloadedBytes, let total = progress.compressedDiskBytes {
        "Downloading disk: \(Self.bytes(downloaded)) of \(Self.bytes(total))"
      } else {
        "Downloading disk..."
      }
    case .pullingNVRAM:
      "Downloading NVRAM and creating the local image..."
    }
  }

  static func bytes(_ value: Int64) -> String {
    value.formatted(.byteCount(style: .file, spellsOutZero: false))
  }
}
