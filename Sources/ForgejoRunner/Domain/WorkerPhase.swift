import Foundation

nonisolated enum WorkerPhase: String, Equatable, Sendable {
  case stopped
  case recovering
  case cloning
  case booting
  case waitingForSSH
  case waitingForJob
  case runningJob
  case cleaning
  case retrying
  case failed

  var title: String {
    switch self {
    case .stopped: "Stopped"
    case .recovering: "Recovering"
    case .cloning: "Cloning VM"
    case .booting: "Booting VM"
    case .waitingForSSH: "Waiting for SSH"
    case .waitingForJob: "Waiting for a job"
    case .runningJob: "Running a job"
    case .cleaning: "Deleting VM"
    case .retrying: "Retrying"
    case .failed: "Failed"
    }
  }

  var isWorking: Bool {
    switch self {
    case .recovering, .cloning, .booting, .waitingForSSH, .runningJob, .cleaning:
      true
    case .stopped, .waitingForJob, .retrying, .failed:
      false
    }
  }
}
