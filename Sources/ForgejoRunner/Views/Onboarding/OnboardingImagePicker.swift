import SwiftUI

struct OnboardingImagePicker: View {
  @Environment(AppModel.self) private var model
  @Environment(OnboardingImageChoice.self) private var choice
  @State private var catalog = CatalogState.loading

  var body: some View {
    @Bindable var choice = choice
    VStack(spacing: 12) {
      if let error = model.imageErrorMessage {
        Banner(message: error, style: .error)
      }
      CatalogImageList(
        catalog: catalog, source: $choice.source, name: $choice.name,
        downloadedNames: Set(model.images.map(\.name))
      ) {
        Task { await loadCatalog() }
      }
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .padding(.horizontal, 30)
    .padding(.top, 12)
    .padding(.bottom, 4)
    .task { await loadCatalog() }
    .task { await model.refreshImages() }
  }

  private func loadCatalog() async {
    catalog = .loading
    do {
      catalog = .loaded(try await CirrusImageCatalog.fetch())
    } catch {
      catalog = .failed(error.localizedDescription)
    }
  }
}
