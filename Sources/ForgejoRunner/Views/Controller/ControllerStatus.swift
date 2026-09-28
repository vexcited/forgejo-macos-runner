import SwiftUI

// one summary of the controller state shared by the overview, sidebar and menu bar.
enum ControllerStatus: Equatable {
  case stopped
  case failed
  case stopping
  case preparing
  case waiting
  case running
  case retrying
  case busy(WorkerPhase)

  init(coordinator: RunnerCoordinator) {
    if coordinator.isStopping {
      self = .stopping
    } else if !coordinator.isRunning {
      self = coordinator.errorMessage == nil ? .stopped : .failed
    } else if coordinator.isPreparing {
      self = .preparing
    } else {
      switch coordinator.orderedStatuses.first?.phase {
      case .waitingForJob: self = .waiting
      case .runningJob: self = .running
      case .retrying: self = .retrying
      case .failed: self = .failed
      case .some(let phase): self = .busy(phase)
      case nil: self = .preparing
      }
    }
  }

  var title: String {
    switch self {
    case .stopped: "Stopped"
    case .failed: "Needs attention"
    case .stopping: "Stopping safely"
    case .preparing: "Preparing"
    case .waiting: "Waiting for a job"
    case .running: "Running a job"
    case .retrying: "Retrying"
    case .busy(let phase): phase.title
    }
  }

  var symbol: String {
    switch self {
    case .stopped: "pause.fill"
    case .failed: "exclamationmark"
    case .stopping: "stop.fill"
    case .preparing: "gearshape.2.fill"
    case .waiting: "checkmark"
    case .running: "hammer.fill"
    case .retrying: "arrow.clockwise"
    case .busy: "shippingbox.fill"
    }
  }

  var tint: Color {
    switch self {
    case .stopped, .stopping: .gray
    case .failed: .red
    case .preparing, .busy: .blue
    case .waiting: .green
    case .running: .indigo
    case .retrying: .orange
    }
  }

  var isActive: Bool {
    switch self {
    case .preparing, .running, .busy, .stopping: true
    case .stopped, .failed, .waiting, .retrying: false
    }
  }
}
