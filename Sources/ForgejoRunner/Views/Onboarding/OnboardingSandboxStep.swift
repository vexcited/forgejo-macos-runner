import SwiftUI

// shows one state at a time: fix what is missing, check again, then set dns.
struct OnboardingSandboxStep: View {
  @Environment(AppModel.self) private var model
  @State private var isChecking = false

  var body: some View {
    let phase = OnboardingSandboxPhase(model: model)
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
        OnboardingStepHeader(
          symbol: phase.symbol, tint: phase.tint, title: phase.title, subtitle: phase.message)
        content(for: phase)
          .padding(.top, 18)
      }
      .id(phase)
      .transition(.blurFade)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(.smooth(duration: 0.4), value: phase)
    .task { await checkAgain() }
  }

  @ViewBuilder
  private func content(for phase: OnboardingSandboxPhase) -> some View {
    switch phase {
    case .checking:
      ProgressView()
        .controlSize(.small)
    case .tartMissing:
      VStack(spacing: 16) {
        CommandText(command: "brew install openai/tools/tart")
        checkAgainButton
      }
    case .needsAttention:
      checkAgainButton
    case .needsPrivileges:
      VStack(spacing: 12) {
        Button("Set Up Sandbox") { Task { await model.setUpSandbox() } }
          .glassButtonStyle(prominent: true)
          .disabled(model.isSettingUpSandbox)
        if let error = model.sandboxErrorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 440)
        }
      }
    case .ready:
      Form {
        Section {
          SandboxDNSField()
        } footer: {
          Text("The DNS servers jobs use. The default is fine for most people.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .frame(maxWidth: 520)
    }
  }

  private var checkAgainButton: some View {
    Button {
      Task { await checkAgain() }
    } label: {
      if isChecking {
        ProgressView().controlSize(.small)
      } else {
        Text("Check Again")
      }
    }
    .glassButtonStyle()
    .disabled(isChecking)
  }

  private func checkAgain() async {
    isChecking = true
    await model.refreshSandboxStatus()
    isChecking = false
  }
}
