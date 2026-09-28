import Foundation

// the line under the status title, saying what the state means right now.
@MainActor
struct HomeStatusDetail {
  let model: AppModel

  var text: String {
    let coordinator = model.coordinator
    if coordinator.isStopping {
      return "Stopping the VM and deleting it"
    }
    if let error = coordinator.errorMessage, !coordinator.isRunning {
      return error
    }
    if coordinator.isRunning {
      if let pool = coordinator.orderedStatuses.first, let detail = pool.detail,
        pool.phase != .waitingForJob
      {
        return detail
      }
      return image
    }
    if model.connections.connections.isEmpty {
      return "Add a connection to take jobs"
    }
    return "Not taking jobs"
  }

  private var image: String {
    let name = CirrusImageName(packageName: model.preferences.selectedImage)
    return name.release.map { "macOS \($0.name)" } ?? model.preferences.selectedImage
  }
}
