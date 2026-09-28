import Foundation

nonisolated struct ProvisioningResources: Sendable {
  // both guest tools are native Swift binaries embedded in the app bundle. the
  // provisioner runs once inside the golden image; the one-job helper is installed
  // into the image and runs in every disposable clone.
  let guestProvisioner: URL
  let guestHelper: URL

  static func bundled() throws -> ProvisioningResources {
    guard
      let guestProvisioner = Bundle.main.url(
        forResource: "forgejo-guest-provision", withExtension: nil),
      let guestHelper = Bundle.main.url(forResource: "forgejo-one-job", withExtension: nil)
    else {
      throw ProvisioningError.resourcesMissing
    }
    return ProvisioningResources(guestProvisioner: guestProvisioner, guestHelper: guestHelper)
  }
}
