import Foundation

// points tart at the executable from the preferences while no controller is using it.
struct TartConfigurator {
  let tart: TartClient
  let paths: AppPaths
  let preferences: AppPreferences
  let coordinator: RunnerCoordinator

  func configure() {
    guard !coordinator.isRunning else { return }
    tart.configure(
      factory: TartCommandFactory(
        executableURL: URL(filePath: preferences.tartExecutablePath),
        tartHome: paths.tartHome,
        baseEnvironment: CommandEnvironment.make(homeDirectory: paths.homeDirectory)
      )
    )
  }
}
