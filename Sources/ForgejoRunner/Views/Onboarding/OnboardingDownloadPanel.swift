import SwiftUI

struct OnboardingDownloadPanel: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(spacing: 22) {
      Spacer()
      VStack(spacing: 4) {
        Text("Step 1 of 2")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Downloading \(title)")
          .font(.title3.weight(.semibold))
      }
      TimelineView(.periodic(from: .now, by: 0.25)) { context in
        readout(at: context.date)
      }
      .controlSize(.large)
      Spacer()
      Spacer()
    }
    .padding(.horizontal, 48)
  }

  private var progress: TartCloneProgress? { model.cloneProgress }

  private func readout(at date: Date) -> some View {
    let fraction = progress?.shownFraction(at: date)
    let seconds = progress?.remainingTime(at: date)?.components.seconds ?? 0
    return VStack(spacing: 8) {
      if let fraction {
        ProgressView(value: fraction)
          .animation(.linear(duration: 0.25), value: fraction)
      } else {
        ProgressView()
          .progressViewStyle(.linear)
      }
      HStack(alignment: .firstTextBaseline) {
        Text(detail(at: date))
          .foregroundStyle(.secondary)
        Spacer()
        if let fraction {
          Text(fraction, format: .percent.precision(.fractionLength(fraction < 0.1 ? 1 : 0)))
            .contentTransition(.numericText(value: fraction))
            .animation(.smooth(duration: 0.25), value: fraction)
        }
      }
      .font(.callout.monospacedDigit())
      Text(remaining(at: date))
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .contentTransition(.numericText(countsDown: true))
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.4), value: seconds / 60)
    }
  }

  private var title: String {
    guard let source = model.activeClone?.source else { return "" }
    let image = CirrusImageName(source: source)
    return image.hasXcode ? "\(image.title) with Xcode" : image.title
  }

  private func detail(at date: Date) -> String {
    switch progress?.phase ?? .starting {
    case .starting, .pullingManifest:
      "Starting..."
    case .pullingDisk:
      if let bytes = progress?.shownBytes(at: date), let total = progress?.compressedDiskBytes {
        "\(CloneProgressPanel.bytes(bytes)) of \(CloneProgressPanel.bytes(total))"
      } else {
        "Downloading..."
      }
    case .pullingNVRAM:
      "Finishing..."
    }
  }

  private func remaining(at date: Date) -> String {
    guard let time = progress?.remainingTime(at: date) else { return "Estimating time left..." }
    if time < .seconds(60) { return "Less than a minute left" }
    let text = time.formatted(
      .units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2))
    return "About \(text) left"
  }
}
