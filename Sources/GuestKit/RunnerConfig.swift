import Foundation

public enum RunnerConfig {
  // forgejo-runner requires a token, the host broker replaces this one on every call.
  public static let placeholderToken = "brokered"

  private struct Document: Encodable {
    struct Runner: Encodable {
      let file: String
      let capacity: Int
      // lets the runner accept the broker's self-signed certificate, see processEnvironment.
      let insecure: Bool
      let envs: [String: String]
    }
    struct Host: Encodable {
      let workdirParent: String
      enum CodingKeys: String, CodingKey {
        case workdirParent = "workdir_parent"
      }
    }
    struct Connection: Encodable {
      let url: String
      let uuid: String
      let token: String
      let labels: [String]
    }
    struct Server: Encodable {
      let connections: [String: Connection]
    }
    let runner: Runner
    let host: Host
    let server: Server
  }

  // jobs inherit the runner process environment, so these values keep the broker
  // settings of processEnvironment away from every step.
  static let jobEnvironmentOverrides = [
    "HTTPS_PROXY": "", "https_proxy": "", "HTTP_PROXY": "", "http_proxy": "",
    "ALL_PROXY": "", "all_proxy": "", "GIT_CONFIG_COUNT": "0",
  ]

  public static func yaml(assignment: GuestAssignment, runnerFile: String, workDir: String)
    throws -> String
  {
    let connection = Document.Connection(
      url: assignment.url, uuid: assignment.uuid, token: placeholderToken,
      labels: assignment.labels)
    let document = Document(
      runner: Document.Runner(
        file: runnerFile, capacity: 1, insecure: true, envs: jobEnvironmentOverrides),
      host: Document.Host(workdirParent: workDir),
      server: Document.Server(connections: [assignment.name: connection])
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(document)
    return String(decoding: data, as: UTF8.self) + "\n"
  }

  // the runner process reaches forgejo only through the broker. its go client honors
  // HTTPS_PROXY, while git gets an empty http.proxy so action and workflow clones go
  // straight to the real servers, and keeps verifying tls for the instance even though
  // runner.insecure asks it not to.
  public static func processEnvironment(
    base: [String: String], assignment: GuestAssignment
  ) -> [String: String] {
    var environment = base.filter { key, _ in
      !["https_proxy", "http_proxy", "all_proxy", "no_proxy"].contains(key.lowercased())
        && !key.hasPrefix("GIT_CONFIG_")
    }
    environment["HTTPS_PROXY"] = assignment.proxyURL
    environment["GIT_CONFIG_COUNT"] = "2"
    environment["GIT_CONFIG_KEY_0"] = "http.proxy"
    environment["GIT_CONFIG_VALUE_0"] = ""
    environment["GIT_CONFIG_KEY_1"] = "http.\(assignment.url).sslVerify"
    environment["GIT_CONFIG_VALUE_1"] = "true"
    return environment
  }
}
