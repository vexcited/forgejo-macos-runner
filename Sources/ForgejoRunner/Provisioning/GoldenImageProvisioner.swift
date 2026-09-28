import Foundation
import GuestKit

// Pure-Swift replacement for the former provision-golden-image.sh host orchestrator.
// It drives Tart and SSH directly, so every command flows through ProcessExecutor
// and is logged; only the guest payloads remain shell (they run inside the VM).
@MainActor
final class GoldenImageProvisioner {
  private let tart: TartProvisioning
  private let identity: ControllerSSHIdentity

  init(
    tart: TartProvisioning,
    commands: CommandExecuting,
    paths: AppPaths,
    baseEnvironment: [String: String],
    sshKeygenURL: URL = URL(filePath: "/usr/bin/ssh-keygen")
  ) {
    self.tart = tart
    identity = ControllerSSHIdentity(
      commands: commands,
      paths: paths,
      baseEnvironment: baseEnvironment,
      sshKeygenURL: sshKeygenURL
    )
  }

  func provision(
    settings: GoldenImageSettings,
    resources: ProvisioningResources,
    logHandler: @escaping @MainActor @Sendable (String) -> Void,
    outputHandler: @escaping @MainActor @Sendable (String) -> Void
  ) async throws {
    logHandler("Confirming golden image \(settings.image) exists and is stopped.")
    let images = try await tart.images()
    guard let image = images.first(where: { $0.name == settings.image }) else {
      throw ProvisioningError.imageMissing(settings.image)
    }
    guard !image.isRunning, image.state.lowercased() == "stopped" else {
      throw ProvisioningError.imageNotStopped(settings.image)
    }

    let publicKey = try await identity.ensurePublicKey(logHandler: logHandler)

    // the pristine image still accepts the well-known admin password over ssh, so it
    // boots where nothing on the network can connect into it, and every step goes
    // through the tart guest agent instead of the network.
    logHandler(
      "Booting \(settings.image) sandboxed, without graphics, audio, or clipboard sharing.")
    let boot = ProvisioningBoot(
      tart: tart, settings: settings, networkMode: .provisioning, logHandler: logHandler)
    let guest = boot.guest

    do {
      try await boot.waitUntilReady(settings)
      try await GuestAgentCommandChannel.configure(through: guest, logHandler: logHandler)

      logHandler("Staging the native guest provisioner in the VM.")
      let program = try Data(contentsOf: resources.guestProvisioner)
      let staged = try await guest.run(
        "f=$(mktemp /private/tmp/forgejo-provision.XXXXXX) && cat > \"$f\" && chmod 0755 \"$f\" && printf %s \"$f\"",
        standardInput: program, timeout: .seconds(120))
      let remotePath = staged.outputString.trimmingCharacters(in: .whitespacesAndNewlines)
      guard remotePath.hasPrefix("/private/tmp/forgejo-provision."),
        remotePath.dropFirst("/private/tmp/forgejo-provision.".count).allSatisfy({
          $0.isASCII && ($0.isLetter || $0.isNumber)
        })
      else {
        throw ProvisioningError.stagingFailed
      }

      logHandler("Provisioning Xcode, Node, Go, SSH hardening, and Forgejo Runner in the guest.")
      let arguments = [
        remotePath, settings.runnerVersion, publicKey, settings.xcodeApplicationPath,
      ]
      _ = try await guest.run(
        arguments.map(GuestAgentChannel.singleQuoted).joined(separator: " ") + " </dev/null",
        timeout: .seconds(7_200), outputHandler: outputHandler)
      logHandler("The guest provisioner completed; SSH is key-only.")
      _ = try? await guest.run(
        "rm -f \(GuestAgentChannel.singleQuoted(remotePath))", timeout: .seconds(30))

      logHandler("Installing the secure one-job guest helper.")
      let helper = try Data(contentsOf: resources.guestHelper)
      _ = try await guest.run(
        "temporary=$(mktemp /private/tmp/forgejo-one-job.XXXXXX); trap 'rm -f \"$temporary\"' EXIT; cat > \"$temporary\"; sudo install -d -m 0755 /usr/local/libexec; sudo install -m 0755 \"$temporary\" /usr/local/libexec/forgejo-one-job",
        standardInput: helper, timeout: .seconds(120))

      // sessions prepare their sandbox through the same agent, as root, so this checks
      // the exact path every runner session depends on.
      logHandler("Verifying the guest helper and Forgejo Runner flags through the guest agent.")
      let validation = try await guest.run(
        "sudo -n /usr/local/libexec/forgejo-one-job --validate", timeout: .seconds(120),
        outputHandler: outputHandler)
      guard validation.outputString.contains(RunnerSessionProtocol.validationMarker) else {
        throw ProvisioningError.guestAgentUnavailable
      }

      logHandler("Flushing the guest filesystem so late writes persist into clones.")
      // the boot firewall must survive into every clone.
      try await boot.shutDownCleanly()
    } catch {
      await boot.tearDown()
      throw error
    }

    await boot.tearDown()
    logHandler("Golden image provisioning completed successfully.")
  }

  // Pins the golden image host key under a wildcard so every clone (which shares
  // the key but gets a new IP) verifies against it.
}
