import Foundation

setenv("LC_ALL", "C", 1)
umask(0o077)

// shared with the signal handler, which may only touch plain globals.
nonisolated(unsafe) var currentChild: pid_t = 0
nonisolated(unsafe) var caughtSignal: Int32 = 0

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "--find-xcode" {
  XcodeLocator.runFindMode(arguments)
}

guard arguments.count == 2 || arguments.count == 3 else {
  Console.error("usage: forgejo-guest-provision <runner-version> <ssh-public-key> [xcode-app]")
  exit(64)
}

let provision = GoldenGuestProvision(
  runnerVersion: arguments[0], sshPublicKey: arguments[1],
  requestedXcode: arguments.count == 3 ? arguments[2] : "")

for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
  _ = signal(signalNumber) { received in
    caughtSignal = received
    if currentChild > 0 { kill(currentChild, SIGTERM) }
  }
}

exit(provision.run())
