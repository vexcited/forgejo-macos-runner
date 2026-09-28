import SwiftUI

struct CardHeader<Accessory: View>: View {
  let title: String
  let symbol: String
  @ViewBuilder var accessory: Accessory

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Label(title, systemImage: symbol)
        .font(.headline)
        .labelStyle(.titleAndIcon)
      Spacer()
      accessory
    }
  }
}
