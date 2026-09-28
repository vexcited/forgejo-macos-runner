import Foundation

// lists the macos-image-templates packages from the public github page, since the
// packages rest api requires a token even for public packages.
nonisolated enum CirrusImageCatalog {
  private static let listingURL = URL(
    string: "https://github.com/orgs/cirruslabs/packages?repo_name=macos-image-templates")!
  private static let maximumPages = 10

  static func fetch(session: URLSession = .shared) async throws -> [CatalogImage] {
    var images: [String: CatalogImage] = [:]
    for page in 1...maximumPages {
      var components = URLComponents(url: listingURL, resolvingAgainstBaseURL: false)!
      components.queryItems?.append(URLQueryItem(name: "page", value: String(page)))
      let (data, response) = try await session.data(from: components.url!)
      if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
        throw CirrusImageCatalogError.unexpectedStatus(status)
      }
      let pageImages = parse(String(decoding: data, as: UTF8.self))
        .filter { images[$0.name] == nil }
      guard !pageImages.isEmpty else { break }
      for image in pageImages {
        images[image.name] = image
      }
    }
    // vanilla images ship without the tart guest agent, which every runner session
    // needs to prepare its sandbox, so they are not offered. images without a known
    // macos release, such as macos-runner, are left out too.
    let usable = images.values.filter {
      !$0.name.hasSuffix("-vanilla") && $0.parsedName.release != nil
    }
    guard !usable.isEmpty else { throw CirrusImageCatalogError.noImages }
    return usable.sorted { $0.publishedAt > $1.publishedAt }
  }

  static func parse(_ html: String) -> [CatalogImage] {
    let dates = ISO8601DateFormatter()
    return html.components(separatedBy: #"<li class="Box-row">"#).dropFirst().compactMap { row in
      guard
        let name = row.firstMatch(of: /\/packages\/container\/package\/([A-Za-z0-9._-]+)"/)?.1,
        let datetime = row.firstMatch(of: /<relative-time datetime="([^"]+)"/)?.1,
        let publishedAt = dates.date(from: String(datetime))
      else { return nil }
      let downloads = row.firstMatch(of: /octicon-download[\s\S]*?<\/svg>\s*([^<\s]+)/)?.1
      return CatalogImage(
        name: String(name), publishedAt: publishedAt, downloads: downloads.map(String.init) ?? "0")
    }
  }
}
