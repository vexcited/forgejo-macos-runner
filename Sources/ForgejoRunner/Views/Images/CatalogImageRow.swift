import SwiftUI

struct CatalogImageRow: View {
  let image: CatalogImage
  var isDownloaded = false

  var body: some View {
    HStack(spacing: 12) {
      MacOSReleaseBadge(image: image.parsedName)
      VStack(alignment: .leading, spacing: 2) {
        Text(image.parsedName.title)
          .font(.headline)
        Text(image.parsedName.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if isDownloaded {
        Chip(text: "Downloaded", symbol: "checkmark.circle")
          .help("Already on this Mac, no download needed")
      }
      Chip(text: image.downloads, symbol: "arrow.down.circle")
        .help("\(image.downloads) downloads")
    }
    .padding(.vertical, 4)
    .help(image.name)
  }
}
