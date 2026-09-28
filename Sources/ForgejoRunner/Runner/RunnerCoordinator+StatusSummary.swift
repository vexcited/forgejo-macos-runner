import Foundation

extension RunnerCoordinator {
  var orderedStatuses: [WorkerStatus] {
    statuses.values.sorted {
      $0.connectionName.localizedStandardCompare($1.connectionName) == .orderedAscending
    }
  }

  var isWorking: Bool {
    isPreparing || statuses.values.contains(where: { $0.phase.isWorking })
  }

  var waitingCount: Int {
    statuses.values.filter { $0.phase == .waitingForJob }.count
  }
}
