import SwiftUI

struct GoldenImagePromptView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let prompt: GoldenImagePrompt
  @State private var useAsGolden: Bool

  init(prompt: GoldenImagePrompt) {
    self.prompt = prompt
    _useAsGolden = State(initialValue: prompt.useByDefault)
  }

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(
        title: "\(prompt.imageName) is ready",
        subtitle: "The download finished."
      )
      Divider()
      Form {
        Section {
          Toggle("Use as the golden runner image", isOn: $useAsGolden)
          Text(
            "The golden image is provisioned automatically: Xcode selection and license, Node, Go, SSH hardening, and the Forgejo runner. This can take several minutes."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      Divider()
      HStack {
        Button("Not Now", role: .cancel) {
          Task { await model.resolveGoldenPrompt(use: false) }
        }
        .keyboardShortcut(.cancelAction)
        Spacer()
        Button(useAsGolden ? "Use and Provision" : "Done") {
          Task { await model.resolveGoldenPrompt(use: useAsGolden) }
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
      .padding()
    }
    .frame(width: 540, height: 320)
  }
}
