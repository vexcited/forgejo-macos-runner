import Foundation

struct ImageUpdateTarget: Identifiable {
  let image: TartImage
  let repository: String

  var id: String { image.name }
}
