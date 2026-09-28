// how long the controller waits for each vm step. these are fixed, not settings.
nonisolated enum RunnerTimeouts {
  static let vmBootSeconds = 180
  // how long the tart guest agent may take to answer while provisioning.
  static let guestAgentSeconds = 300
  static let sshSeconds = 120
  static let runnerSessionSeconds = 86_400
  // the first retry delay, which doubles up to five minutes.
  static let retryDelaySeconds = 15
}
