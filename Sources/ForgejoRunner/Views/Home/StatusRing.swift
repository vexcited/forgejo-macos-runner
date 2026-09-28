import SwiftUI

// the state of the runner as one ring around the forgejo mark. a spinning arc means
// work is in progress, a full ring means the runner is settled in that state.
struct StatusRing: View {
  let status: ControllerStatus
  private let size: CGFloat = 176
  private let lineWidth: CGFloat = 10

  var body: some View {
    ZStack {
      Circle()
        .stroke(.quaternary, lineWidth: lineWidth)
      if status.isActive {
        SpinningArc(tint: status.tint, lineWidth: lineWidth)
          .transition(.opacity)
      } else {
        Circle()
          .stroke(status.tint.opacity(status == .stopped ? 0.35 : 1), lineWidth: lineWidth)
          .transition(.opacity)
      }
      ForgejoMarkShape()
        .fill(status == .stopped ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
        .frame(width: size * 0.4, height: size * 0.4)
    }
    .frame(width: size, height: size)
    .animation(.smooth(duration: 0.5), value: status)
    .accessibilityElement()
    .accessibilityLabel(status.title)
  }
}

// an arc that stretches and shrinks as it chases its own tail, fading like a comet
// from its bright head, over a slow drift so it never stops at the same place.
private struct SpinningArc: View {
  let tint: Color
  let lineWidth: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let cycle = 1.8
  private static let shortest = 0.08
  private static let stretch = 0.62

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      let (head, length) = reduceMotion ? (0.25, 0.3) : Self.arc(at: time)
      ZStack {
        comet(length: length)
          .blur(radius: 7)
          .opacity(0.55)
        comet(length: length)
      }
      .rotationEffect(.degrees((head - length) * 360 - 90))
    }
  }

  private func comet(length: Double) -> some View {
    Circle()
      .trim(from: 0, to: length)
      .stroke(
        AngularGradient(
          colors: [tint.opacity(0.05), tint.opacity(0.6), tint],
          center: .center, startAngle: .zero, endAngle: .degrees(length * 360)),
        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
  }

  // the head races ahead in the first half of a cycle and the tail catches up in the
  // second, while the whole arc drifts forward a little faster each lap.
  private static func arc(at time: Double) -> (head: Double, length: Double) {
    let laps = time / cycle
    let lap = laps.rounded(.down)
    let progress = laps - lap
    let grow = ease(min(progress * 2, 1))
    let shrink = ease(max(progress * 2 - 1, 0))
    let tail = lap * stretch + shrink * stretch + laps * 0.2
    let head = lap * stretch + grow * stretch + laps * 0.2 + shortest
    return (head.truncatingRemainder(dividingBy: 1), head - tail)
  }

  private static func ease(_ value: Double) -> Double {
    value < 0.5 ? 4 * value * value * value : 1 - pow(-2 * value + 2, 3) / 2
  }
}
