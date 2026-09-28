import Foundation

// speaks the connect protocol of the forgejo runner service with a runner token that
// never leaves this mac.
nonisolated struct ForgejoRunnerAPI: Sendable {
  static let runnerService = "runner.v1.RunnerService"
  static let pingService = "ping.v1.PingService"

  struct Response: Sendable {
    let status: Int
    let contentType: String?
    let body: Data
  }

  let session: URLSession
  let userAgent: String

  init(runnerVersion: String) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    configuration.urlCredentialStorage = nil
    configuration.timeoutIntervalForRequest = 60
    self.init(session: URLSession(configuration: configuration), runnerVersion: runnerVersion)
  }

  init(session: URLSession, runnerVersion: String) {
    self.session = session
    userAgent = "forgejo-runner/v\(runnerVersion)"
  }

  // the path forgejo-runner uses for a method, relative to the instance url.
  static func path(for connection: RunnerConnection, service: String, method: String) -> String {
    connection.basePath + "/api/actions/\(service)/\(method)"
  }

  func call(
    _ method: String,
    body: Data,
    connection: ResolvedRunnerConnection,
    requestKey: UUID? = nil
  ) async throws -> Data {
    var headers = ["Content-Type": "application/proto", "Connect-Protocol-Version": "1"]
    if let requestKey {
      headers["x-runner-request-key"] = requestKey.uuidString.lowercased()
    }
    let response = try await send(
      path: Self.path(for: connection.connection, service: Self.runnerService, method: method),
      headers: headers,
      body: body,
      connection: connection
    )
    guard response.status == 200 else {
      throw ForgejoRunnerAPIError.rejected(
        method: method, status: response.status, message: Self.errorMessage(in: response.body))
    }
    return response.body
  }

  // sends a runner call with the real uuid and token of the connection, whatever the
  // caller put in those headers.
  func send(
    path: String,
    headers: [String: String],
    body: Data,
    connection: ResolvedRunnerConnection
  ) async throws -> Response {
    guard let url = URL(string: path, relativeTo: connection.connection.url)?.absoluteURL,
      url.scheme == "https",
      url.host() == connection.connection.url.host(),
      url.port == connection.connection.url.port
    else {
      throw ForgejoRunnerAPIError.invalidPath(path)
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.setValue(
      connection.connection.uuid.uuidString.lowercased(), forHTTPHeaderField: "x-runner-uuid")
    request.setValue(connection.token, forHTTPHeaderField: "x-runner-token")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    let (data, response) = try await session.data(for: request, delegate: NoRedirects.shared)
    guard let http = response as? HTTPURLResponse else {
      throw ForgejoRunnerAPIError.invalidResponse
    }
    return Response(
      status: http.statusCode,
      contentType: http.value(forHTTPHeaderField: "Content-Type"),
      body: data
    )
  }

  private static func errorMessage(in body: Data) -> String {
    struct ConnectError: Decodable {
      let code: String?
      let message: String?
    }
    guard let error = try? JSONDecoder().decode(ConnectError.self, from: body) else {
      return String(decoding: body.prefix(200), as: UTF8.self)
    }
    return [error.code, error.message].compactMap { $0 }.joined(separator: ": ")
  }
}
