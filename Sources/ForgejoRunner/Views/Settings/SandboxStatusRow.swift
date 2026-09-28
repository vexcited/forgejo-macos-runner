import SwiftUI

struct SandboxStatusRow: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(tint)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
        if model.sandboxStatus != nil, !model.isTartInstalled {
          HStack(spacing: 6) {
            Text("You have to run")
              .font(.caption)
              .foregroundStyle(.secondary)
            CommandText(command: "brew install openai/tools/tart")
          }
        } else {
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 12)
      if model.sandboxStatus == nil {
        ProgressView()
          .controlSize(.small)
      } else if model.isTartInstalled, case .needsPrivileges = model.sandboxStatus {
        Button("Set Up Sandbox") { Task { await model.setUpSandbox() } }
          .disabled(model.isSettingUpSandbox)
      } else {
        Button("Check Again") { Task { await model.refreshSandboxStatus() } }
      }
    }
  }

  private var isReady: Bool {
    model.isTartInstalled && model.sandboxStatus == .ready
  }

  private var symbol: String {
    isReady ? "checkmark.shield.fill" : "exclamationmark.shield"
  }

  private var tint: Color {
    if model.sandboxStatus == nil { return .secondary }
    return isReady ? .green : .orange
  }

  private var title: String {
    if model.sandboxStatus == nil { return "Checking..." }
    if !model.isTartInstalled { return "One install needed" }
    return isReady ? "The sandbox is ready" : "The sandbox needs attention"
  }

  private var detail: String {
    if isReady { return model.preferences.tartExecutablePath }
    return model.sandboxStatus?.problem ?? ""
  }
}
