import SwiftUI

struct ConnectionEditorView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let presentation: ConnectionPresentation

  @State private var name: String
  @State private var url: String
  @State private var uuid: String
  @State private var token: String
  @State private var labels: [String]
  @State private var labelDraft = ""
  @FocusState private var isLabelFieldFocused: Bool
  @State private var isSaving = false
  @State private var isConfirmingRemoval = false
  @State private var errorMessage: String?

  init(presentation: ConnectionPresentation) {
    self.presentation = presentation
    let connection = presentation.connection
    _name = State(initialValue: connection?.name ?? "")
    _url = State(initialValue: connection?.url.absoluteString ?? "")
    _uuid = State(initialValue: connection?.uuid.uuidString.lowercased() ?? "")
    _token = State(initialValue: connection?.token.rawValue ?? "")
    _labels = State(initialValue: connection?.labelNames ?? ["macos-latest"])
  }

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(
        title: presentation.connection == nil ? "New Connection" : "Edit Connection",
        subtitle: "A persistent runner registration from any Forgejo scope."
      )
      Divider()
      Form {
        Section("Connection") {
          TextField("Local name", text: $name, prompt: Text("organization"))
          // verbatim, or the placeholder turns into a link.
          TextField("Forgejo URL", text: $url, prompt: Text(verbatim: "https://codeberg.org"))
        }
        RunnerCredentialsSection(uuid: $uuid, token: $token)
        Section {
          LabelsField(
            labels: $labels, draft: $labelDraft, isFocused: $isLabelFieldFocused,
            suggestions: labelSuggestions)
        } header: {
          Text("Labels")
        } footer: {
          Text(
            "Workflows pick this runner with runs-on set to one of these labels. Press Return or type a comma to add one."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        if let errorMessage {
          Section {
            Banner(message: errorMessage, style: .error)
          }
        }
      }
      .formStyle(.grouped)

      Divider()
      HStack {
        if presentation.connection != nil {
          Button("Remove Connection", role: .destructive) { isConfirmingRemoval = true }
            .disabled(isSaving)
        }
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        if isSaving {
          ProgressView()
            .controlSize(.small)
        }
        // return adds the typed label instead of saving while the label field has text.
        Button("Save Connection") { save() }
          .keyboardShortcut(isLabelFieldFocused && !labelDraft.isEmpty ? nil : .defaultAction)
          .buttonStyle(.borderedProminent)
          .disabled(isSaving)
      }
      .padding()
    }
    .frame(width: 580, height: 660)
    .alert(
      "Remove \(presentation.connection?.name ?? "connection")?",
      isPresented: $isConfirmingRemoval
    ) {
      Button("Remove", role: .destructive) { remove() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The runner stays registered in Forgejo. Delete it there too if you no longer need it.")
    }
  }

  // labels that describe the golden image, offered with one click.
  private var labelSuggestions: [String] {
    let image = CirrusImageName(packageName: model.preferences.selectedImage)
    var names = ["macos-latest"]
    if let release = image.release {
      names.append("macos-\(release.version)")
    }
    names.append("macos-arm64")
    if image.hasXcode {
      names.append("xcode")
    }
    return names
  }

  private func remove() {
    guard let connection = presentation.connection else { return }
    isSaving = true
    Task {
      defer { isSaving = false }
      do {
        try await model.removeConnection(connection)
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func save() {
    do {
      let pendingLabels = LabelsField.names(in: labelDraft).filter { !labels.contains($0) }
      let connection = try RunnerConnection.validated(
        name: name,
        url: url,
        uuid: uuid,
        token: token,
        labels: labels + pendingLabels
      )
      isSaving = true
      Task {
        defer { isSaving = false }
        do {
          try await model.saveConnection(connection, replacing: presentation.originalName)
          dismiss()
        } catch {
          errorMessage = error.localizedDescription
        }
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
