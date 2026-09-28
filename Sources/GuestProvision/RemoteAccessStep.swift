import Foundation

// screen sharing and remote management accept the image's well-known admin password,
// so nothing but key-only ssh stays reachable in the runner vms.
enum RemoteAccessStep {
  static func disable() {
    let environment = ProvisionEnvironment.base
    Console.log("turning off screen sharing and remote management.")
    _ = ProcessRunner.capture(
      "/usr/bin/sudo", ["/bin/launchctl", "disable", "system/com.apple.screensharing"],
      environment: environment)
    _ = ProcessRunner.capture(
      "/usr/bin/sudo", ["/bin/launchctl", "bootout", "system/com.apple.screensharing"],
      environment: environment)
    _ = ProcessRunner.capture(
      "/usr/bin/sudo",
      [
        "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart",
        "-deactivate", "-configure", "-access", "-off",
      ],
      environment: environment)
  }
}
