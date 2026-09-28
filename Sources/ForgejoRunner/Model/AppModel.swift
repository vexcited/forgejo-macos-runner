import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
  let paths: AppPaths
  let preferences: AppPreferences
  let connections: ConnectionStore
  let activity: ActivityLog
  let commandLog: CommandLog
  let loginItem: LoginItemManager
  let coordinator: RunnerCoordinator
  let tartConfigurator: TartConfigurator
  let imageLibrary: ImageLibrary
  let pausedClones: PausedCloneController
  let imageClones: ImageCloneController
  let goldenImages: GoldenImageController
  let sandboxSetup: SandboxSetup

  let commands: ProcessExecutor
  private var didStart = false

  var showsOperationLogs = false
  private(set) var isMainWindowOpen = false

  init(
    paths: AppPaths = .live,
    preferences: AppPreferences = AppPreferences()
  ) {
    self.paths = paths
    self.preferences = preferences
    let commands = ProcessExecutor()
    self.commands = commands
    let commandLog = CommandLog(directory: paths.logsDirectory)
    self.commandLog = commandLog
    commands.commandLog = commandLog
    let activity = ActivityLog()
    self.activity = activity
    let environment = CommandEnvironment.make(homeDirectory: paths.homeDirectory)
    let tart = TartClient(
      commands: commands,
      factory: TartCommandFactory(
        executableURL: URL(filePath: preferences.tartExecutablePath),
        tartHome: paths.tartHome,
        baseEnvironment: environment
      )
    )
    let ssh = SSHClient(
      commands: commands,
      factory: SSHCommandFactory(
        executableURL: URL(filePath: "/usr/bin/ssh"),
        identityFile: paths.sshIdentityFile,
        knownHostsFile: paths.sshSessionKnownHostsFile,
        user: "admin",
        baseEnvironment: environment
      )
    )
    let coordinator = RunnerCoordinator(
      tart: tart,
      ssh: ssh,
      brokerIdentity: { try await BrokerIdentity.shared(commands: commands) },
      caffeine: CaffeineController(commands: commands),
      log: activity,
      controllerLock: ControllerLock(
        fileURL: paths.stateDirectory.appending(path: "controller.lock")
      )
    )
    self.coordinator = coordinator
    connections = ConnectionStore(
      repository: ConnectionsRepository(fileURL: paths.connectionsFile)
    )
    loginItem = LoginItemManager()
    let provisioner = GoldenImageProvisioner(
      tart: tart,
      commands: commands,
      paths: paths,
      baseEnvironment: environment
    )
    let pausedCloneStore = PausedCloneStore(
      fileURL: paths.pausedCloneFile,
      partialDirectory: paths.pausedCloneDirectory,
      tartTemporaryDirectory: paths.tartTemporaryDirectory
    )
    let tartConfigurator = TartConfigurator(
      tart: tart, paths: paths, preferences: preferences, coordinator: coordinator)
    self.tartConfigurator = tartConfigurator
    let imageLibrary = ImageLibrary(
      tart: tart, tartConfigurator: tartConfigurator, preferences: preferences,
      activity: activity, coordinator: coordinator)
    self.imageLibrary = imageLibrary
    let pausedClones = PausedCloneController(
      store: pausedCloneStore, imageLibrary: imageLibrary, activity: activity)
    self.pausedClones = pausedClones
    imageClones = ImageCloneController(
      imageLibrary: imageLibrary, tart: tart, commands: commands,
      spaceReservation: DownloadSpaceReservation(paths: paths),
      tartConfigurator: tartConfigurator, preferences: preferences, activity: activity,
      coordinator: coordinator, pausedClones: pausedClones)
    goldenImages = GoldenImageController(
      imageLibrary: imageLibrary, tart: tart, tartConfigurator: tartConfigurator,
      paths: paths, preferences: preferences, activity: activity,
      coordinator: coordinator, provisioner: provisioner)
    sandboxSetup = SandboxSetup(tart: tart, tartConfigurator: tartConfigurator, activity: activity)
  }

  func start() async {
    guard !didStart else { return }
    didStart = true
    do {
      try paths.prepare()
    } catch {
      imageErrorMessage = error.localizedDescription
      activity.append("Could not prepare app data: \(error.localizedDescription)")
    }
    // a reservation left by a crash would hold free space for nothing.
    DiskReservation.removeLeftovers(of: paths.downloadReservationFile)
    pausedClones.load()
    await connections.load()
    await refreshImages()
    // an install that was set up before the setup flow existed skips it.
    if !preferences.hasCompletedOnboarding, isGoldenImageReady, !connections.connections.isEmpty {
      preferences.hasCompletedOnboarding = true
    }
    if preferences.launchControllerAutomatically, preferences.hasCompletedOnboarding {
      await startController()
    }
  }

  func mainWindowDidOpen() {
    isMainWindowOpen = true
    updateDockPresence()
  }

  func mainWindowDidClose() {
    isMainWindowOpen = false
    updateDockPresence()
  }
}
