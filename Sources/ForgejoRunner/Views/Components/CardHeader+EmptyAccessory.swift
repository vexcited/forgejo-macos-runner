import SwiftUI

extension CardHeader where Accessory == EmptyView {
  init(title: String, symbol: String) {
    self.init(title: title, symbol: symbol) { EmptyView() }
  }
}
