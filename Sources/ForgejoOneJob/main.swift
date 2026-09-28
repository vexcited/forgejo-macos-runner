import Foundation

setenv("LC_ALL", "C", 1)
setenv(
  "PATH", "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin", 1
)

// shared with the signal handler, which may only touch plain globals.
nonisolated(unsafe) var runnerProcessID: pid_t = 0
nonisolated(unsafe) var caughtSignal: Int32 = 0

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "--validate" {
  ValidateMode.run(arguments)
}

if arguments.first == "--prepare" {
  PrepareMode.run(arguments)
}

guard arguments.isEmpty else {
  Console.error("usage: forgejo-one-job")
  exit(64)
}

let job = JobRun.start()
runnerProcessID = job.runner.processIdentifier

// Forward termination to the runner; the exit code below reflects the signal.
for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
  _ = signal(signalNumber) { received in
    caughtSignal = received
    if runnerProcessID > 0 {
      kill(runnerProcessID, SIGTERM)
    }
  }
}

let runnerStatus = job.waitForExit()
if caughtSignal != 0 {
  exit(128 + caughtSignal)
}
exit(runnerStatus)
