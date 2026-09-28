import Foundation
import GuestKit

enum ValidateMode {
  static func run(_ arguments: [String]) -> Never {
    guard arguments.count == 1 else {
      Console.error("usage: forgejo-one-job --validate")
      exit(64)
    }
    Console.log("validating the forgejo runner binary and one-job flags.")
    guard RunnerBinary.validate() else { exit(1) }
    Console.log("forgejo runner validation completed.")
    print(RunnerSessionProtocol.validationMarker)
    exit(0)
  }
}
