import SwiftUI

struct RunnerCredentialsSection: View {
  @Binding var uuid: String
  @Binding var token: String

  var body: some View {
    Section {
      TextField("Runner UUID", text: $uuid, prompt: Text("Shown when you create the runner"))
      SecureField("Runner token", text: $token, prompt: Text("Paste the token from Forgejo"))
    } header: {
      Text("Runner")
    } footer: {
      Text(
        "The token is kept in a file only you can read. It is never logged, and jobs never see it."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}
