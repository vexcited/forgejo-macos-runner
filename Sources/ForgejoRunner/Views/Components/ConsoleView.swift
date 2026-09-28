import SwiftUI

// a scrolling monospaced console that follows new output.
struct ConsoleView: View {
  let output: String
  var placeholder = "No output yet."
  var maxHeight: CGFloat = 220

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(output.isEmpty ? placeholder : output)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(output.isEmpty ? .secondary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
          Color.clear
            .frame(height: 1)
            .id("bottom")
        }
      }
      .frame(minHeight: 100, maxHeight: maxHeight)
      .background(
        Color(nsColor: .textBackgroundColor),
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.hairline, lineWidth: 1)
      }
      .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
      .onChange(of: output) { proxy.scrollTo("bottom", anchor: .bottom) }
    }
  }
}
