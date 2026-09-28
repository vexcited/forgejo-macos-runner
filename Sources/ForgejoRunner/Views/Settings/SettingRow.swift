import SwiftUI

struct SettingRow<Control: View>: View {
  let title: String
  let detail: String
  @ViewBuilder var control: Control

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 12)
      control
        .labelsHidden()
        .toggleStyle(.switch)
    }
  }
}
