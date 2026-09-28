import SwiftUI

struct CatalogImageList: View {
  let catalog: CatalogState
  @Binding var source: String
  @Binding var name: String
  // local image names, so rows already on this mac say so.
  var downloadedNames: Set<String> = []
  let onRetry: () -> Void
  @FocusState private var isFocused: Bool

  var body: some View {
    switch catalog {
    case .loading:
      ProgressView("Loading Cirrus Labs images...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      ContentUnavailableView {
        Label("Images Unavailable", systemImage: "exclamationmark.triangle")
      } description: {
        Text(message)
      } actions: {
        Button("Retry", action: onRetry)
      }
    case .loaded(let images):
      // the list moves its own selection with the arrows once focused, this container
      // only catches the arrows the list did not take.
      VStack(spacing: 0) {
        list(of: images)
      }
      .onKeyPress(.upArrow) { move(by: -1, in: images) }
      .onKeyPress(.downArrow) { move(by: 1, in: images) }
    }
  }

  private func list(of images: [CatalogImage]) -> some View {
    ScrollViewReader { proxy in
      List(images, selection: selection(in: images)) { image in
        CatalogImageRow(image: image, isDownloaded: downloadedNames.contains(image.localName))
          .id(image.id)
      }
      .listStyle(.inset(alternatesRowBackgrounds: true))
      .focused($isFocused)
      .onAppear {
        isFocused = true
        if let selected = images.first(where: { $0.source == source }) {
          proxy.scrollTo(selected.id, anchor: .center)
        }
      }
      .onChange(of: source) {
        if let selected = images.first(where: { $0.source == source }) {
          withAnimation { proxy.scrollTo(selected.id) }
        }
      }
    }
  }

  // arrows move from the selected row, or start at the first one.
  private func move(by offset: Int, in images: [CatalogImage]) -> KeyPress.Result {
    guard !images.isEmpty else { return .ignored }
    let current = images.firstIndex { $0.source == source }
    let next = current.map { min(max($0 + offset, 0), images.count - 1) } ?? 0
    source = images[next].source
    name = images[next].localName
    return .handled
  }

  // the source field is the single source of truth, so typing a matching reference
  // highlights its row and typing anything else clears the selection.
  private func selection(in images: [CatalogImage]) -> Binding<CatalogImage.ID?> {
    Binding(
      get: { images.first { $0.source == source }?.id },
      set: { id in
        guard let image = images.first(where: { $0.id == id }) else { return }
        source = image.source
        name = image.localName
      }
    )
  }
}
