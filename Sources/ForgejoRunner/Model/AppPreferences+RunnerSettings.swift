import Foundation
import GuestKit

extension AppPreferences {
  func runnerSettings(homeDirectory: URL, tartHome: URL) throws -> RunnerSettings {
    guard !selectedImage.isEmpty else {
      throw AppConfigurationError.noImageSelected
    }
    guard !selectedImage.hasPrefix(VMName.controllerPrefix) else {
      throw AppConfigurationError.reservedGoldenImage
    }
    guard
      vmPrefix.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,30}$"#, options: .regularExpression) != nil
    else {
      throw AppConfigurationError.invalidVMPrefix
    }
    guard SessionPreparation.dnsServers(from: sandboxDNSServers) != nil else {
      throw AppConfigurationError.invalidDNSServers
    }
    return RunnerSettings(
      goldenImage: selectedImage,
      vmPrefix: vmPrefix,
      dnsServers: sandboxDNSServers,
      bootTimeoutSeconds: RunnerTimeouts.vmBootSeconds,
      sshTimeoutSeconds: RunnerTimeouts.sshSeconds,
      runnerSessionTimeoutSeconds: RunnerTimeouts.runnerSessionSeconds,
      retryDelaySeconds: RunnerTimeouts.retryDelaySeconds,
      preventSleep: preventSleep,
      runnerVersion: runnerVersion,
      homeDirectory: homeDirectory,
      tartHome: tartHome
    )
  }
}
