import Foundation

// the stock agent also runs a clipboard part, which retries forever in vms booted
// without the clipboard device. every runner vm boots without it so jobs cannot reach
// this mac's clipboard, so clones start the agent with its command channel alone.
// the change applies from the next boot, the running agent is left alone.
@MainActor
enum GuestAgentCommandChannel {
  static let agentPlist = "/Library/LaunchAgents/org.cirruslabs.tart-guest-agent.plist"

  static func configure(
    through guest: GuestAgentChannel,
    logHandler: @escaping @MainActor @Sendable (String) -> Void
  ) async throws {
    logHandler("Starting the guest agent with only its command channel in every clone.")
    let plist = GuestAgentChannel.singleQuoted(agentPlist)
    let result = try await guest.run(
      "agent=$(/usr/bin/plutil -extract ProgramArguments.0 raw \(plist)) && sudo -n /usr/bin/plutil -replace ProgramArguments -json \"[\\\"$agent\\\",\\\"--run-rpc\\\"]\" \(plist) && /usr/bin/plutil -extract ProgramArguments.1 raw \(plist)",
      timeout: .seconds(60))
    guard result.outputString.trimmingCharacters(in: .whitespacesAndNewlines) == "--run-rpc"
    else { throw ProvisioningError.guestAgentUnavailable }
  }
}
