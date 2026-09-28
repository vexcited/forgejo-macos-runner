import Foundation

public struct GuestProvisionInput {
  // The controller key that becomes the sole authorized key in the golden image.
  public static func isEd25519PublicKey(_ value: String) -> Bool {
    value.hasPrefix("ssh-ed25519 ")
  }
}
