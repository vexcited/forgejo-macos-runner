import Foundation

@MainActor
final class CaffeineController: SleepPreventing {
  private let commands: CommandExecuting

  init(commands: CommandExecuting) {
    self.commands = commands
  }

  func run() async throws {
    let request = CommandRequest(
      executableURL: URL(filePath: "/usr/bin/caffeinate"),
      arguments: ["-d", "-i", "-m", "-s"],
      environment: ProcessInfo.processInfo.environment
    )
    let result = try await commands.run(request, timeout: nil, outputHandler: nil)
    guard result.status == 0 else {
      throw CommandFailure(
        executable: "caffeinate", status: result.status, output: result.outputString)
    }
  }
}
