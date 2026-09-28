import Foundation

public enum SSHHardening {
  public static let configFileName = "99-forgejo-ephemeral.conf"

  public static let configText = """
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
    AuthenticationMethods publickey
    PermitRootLogin no
    """

  public static let requiredEffectiveSettings = [
    "passwordauthentication no",
    "kbdinteractiveauthentication no",
    "pubkeyauthentication yes",
    "authenticationmethods publickey",
    "permitrootlogin no",
  ]
}
