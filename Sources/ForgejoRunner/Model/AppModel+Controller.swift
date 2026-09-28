import Foundation

extension AppModel {
  var canStartController: Bool {
    !connections.connections.isEmpty
      && connections.errorMessage == nil
      && !preferences.selectedImage.isEmpty
      && !isImageOperationRunning
  }

  func startController() async {
    guard !coordinator.isRunning else { return }
    await connections.load()
    guard !coordinator.isRunning else { return }
    guard !isImageOperationRunning else {
      coordinator.errorMessage = AppModelError.imageOperationRunning.localizedDescription
      return
    }
    guard connections.errorMessage == nil else {
      coordinator.errorMessage = AppModelError.connectionsUnavailable.localizedDescription
      return
    }
    tartConfigurator.configure()
    do {
      let settings = try preferences.runnerSettings(
        homeDirectory: paths.homeDirectory, tartHome: paths.tartHome)
      coordinator.start(connections: connections.connections, settings: settings)
    } catch {
      coordinator.errorMessage = error.localizedDescription
    }
  }

  func stopController() async {
    await coordinator.stop()
  }

  func saveConnection(_ connection: RunnerConnection, replacing originalName: String?) async throws
  {
    guard !coordinator.isRunning else { throw AppModelError.stopControllerFirst }
    try await connections.save(connection, replacing: originalName)
    activity.append("Saved runner connection \(connection.name).")
  }

  func removeConnection(_ connection: RunnerConnection) async throws {
    guard !coordinator.isRunning else { throw AppModelError.stopControllerFirst }
    try await connections.remove(connection)
    activity.append("Removed runner connection \(connection.name).")
  }
}
