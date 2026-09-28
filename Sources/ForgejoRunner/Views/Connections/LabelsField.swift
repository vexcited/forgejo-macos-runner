import SwiftUI

// the runs-on names of a connection as removable chips with the input right after
// them, like a mail recipient field. the host suffix is added on save.
struct LabelsField: View {
  @Binding var labels: [String]
  @Binding var draft: String
  var isFocused: FocusState<Bool>.Binding
  var suggestions: [String] = []
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      FlowLayout(spacing: 6) {
        ForEach(labels, id: \.self) { label in
          Chip(text: label) {
            labels.removeAll { $0 == label }
          }
        }
        TextField(
          "Label", text: $draft, prompt: Text(labels.isEmpty ? "Add a label" : "Add another")
        )
        .labelsHidden()
        .textFieldStyle(.plain)
        .multilineTextAlignment(.leading)
        .font(.callout.monospaced())
        .frame(width: 150)
        .focused(isFocused)
        .onSubmit { commit() }
        .onKeyPress(.delete) { removeLastWhenEmpty() }
        .onChange(of: draft) { _, newValue in
          if newValue.contains(where: { $0 == "," || $0.isWhitespace }) {
            commit()
          }
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            isFocused.wrappedValue ? Color.accentColor : Color.hairline, lineWidth: 1)
      )
      .contentShape(Rectangle())
      .onTapGesture { isFocused.wrappedValue = true }

      let missing = suggestions.filter { !labels.contains($0) }
      if !missing.isEmpty {
        HStack(spacing: 6) {
          Text("Suggested")
            .font(.caption)
            .foregroundStyle(.secondary)
          ForEach(missing, id: \.self) { name in
            Button {
              labels.append(name)
            } label: {
              HStack(spacing: 3) {
                Image(systemName: "plus")
                  .imageScale(.small)
                Text(name)
              }
              .font(.caption.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [3]))
              )
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Add \(name)")
          }
        }
      }
      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }

  static func names(in draft: String) -> [String] {
    draft.split(whereSeparator: { $0 == "," || $0.isWhitespace })
      .map { RunnerConnection.labelName(from: String($0)) }
  }

  // backspace in an empty input removes the last chip, as in a recipient field.
  private func removeLastWhenEmpty() -> KeyPress.Result {
    guard draft.isEmpty, !labels.isEmpty else { return .ignored }
    labels.removeLast()
    return .handled
  }

  // adds every valid name from the draft and leaves the invalid ones in it for fixing.
  private func commit() {
    let names = Self.names(in: draft)
    let invalid = names.filter { !RunnerConnection.isValidLabelName($0) }
    for name in names where RunnerConnection.isValidLabelName(name) && !labels.contains(name) {
      labels.append(name)
    }
    draft = invalid.joined(separator: " ")
    errorMessage =
      invalid.isEmpty
      ? nil
      : "Start labels with a letter or number and use only letters, numbers, dots, underscores, or hyphens."
  }
}
