import Foundation
import Observation

@MainActor
@Observable
final class ConnectionStore {
  private let repository: ConnectionsRepository

  private(set) var connections: [RunnerConnection] = []
  private(set) var isLoading = false
  var errorMessage: String?

  init(repository: ConnectionsRepository) {
    self.repository = repository
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      connections = try await repository.load()
      errorMessage = nil
    } catch {
      connections = []
      errorMessage = error.localizedDescription
    }
  }

  func save(_ connection: RunnerConnection, replacing originalName: String? = nil) async throws {
    var updated = connections
    if let originalName, let index = updated.firstIndex(where: { $0.name == originalName }) {
      updated[index] = connection
    } else {
      updated.append(connection)
    }
    let document = try ConnectionsDocument.validated(connections: updated)
    try await repository.save(document.connections)
    connections = document.connections
    errorMessage = nil
  }

  func remove(_ connection: RunnerConnection) async throws {
    let updated = connections.filter { $0.id != connection.id }
    try await repository.save(updated)
    connections = updated
    errorMessage = nil
  }
}
