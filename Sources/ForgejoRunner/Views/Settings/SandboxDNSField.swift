import SwiftUI

// the resolvers every job vm uses, saved on submit and when it goes away.
struct SandboxDNSField: View {
  @Environment(AppModel.self) private var model
  @State private var dnsServers = ""

  var body: some View {
    TextField("DNS", text: $dnsServers, prompt: Text("9.9.9.9"))
      .font(.body.monospaced())
      .onSubmit { save() }
      .onAppear { dnsServers = model.preferences.sandboxDNSServers.joined(separator: ", ") }
      .onDisappear { save() }
  }

  private func save() {
    let servers = dnsServers.split(whereSeparator: { $0 == "," || $0.isWhitespace })
      .map(String.init)
    if !servers.isEmpty {
      model.preferences.sandboxDNSServers = servers
    }
  }
}
