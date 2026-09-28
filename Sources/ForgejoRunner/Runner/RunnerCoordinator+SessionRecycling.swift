import Foundation

extension RunnerCoordinator {
  // Restarts the current session on wake, since the VM and SSH connection do not
  // survive the Mac sleeping.
  func handleWake() {
    guard isRunning, !isStopping else { return }
    guard sessionTask != nil else { return }
    log.append("The Mac woke; reconnecting the runner.")
    sessionTask?.cancel()
  }

  // a session vm is blocked from the public networks this mac sat on when it booted.
  // after a network change those can differ, so an idle session is recycled to pick up
  // the new ones. a running job keeps its vm, the next session gets the new rules.
  func recycleIdleSessionAfterNetworkChange() async {
    guard !Task.isCancelled, isRunning, !isStopping,
      sessionTask != nil,
      statuses[Self.poolName]?.phase != .runningJob,
      let current = worker?.sessionBlocks,
      case let latest = await HostAddresses.sandboxBlocks().networks,
      !Task.isCancelled, latest != current,
      // the same session is still idle after the lookup.
      worker?.sessionBlocks == current,
      statuses[Self.poolName]?.phase != .runningJob
    else { return }
    log.append("This Mac moved to another network; recycling the idle runner VM.")
    sessionTask?.cancel()
  }
}
