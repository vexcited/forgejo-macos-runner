import Foundation
import Observation

// keeps a paused or failed clone's partial download so it can resume later.
@MainActor
@Observable
final class PausedCloneController {
  private let store: PausedCloneStore
  private let imageLibrary: ImageLibrary
  private let activity: ActivityLog

  private(set) var pausedClone: PausedClone?

  init(store: PausedCloneStore, imageLibrary: ImageLibrary, activity: ActivityLog) {
    self.store = store
    self.imageLibrary = imageLibrary
    self.activity = activity
  }

  func load() {
    do {
      pausedClone = try store.load()
      if let pausedClone {
        activity.append("A paused clone of \(pausedClone.name) is ready to resume.")
      }
    } catch {
      imageLibrary.errorMessage = error.localizedDescription
      activity.append("Could not read the paused clone: \(error.localizedDescription)")
    }
  }

  func discard() {
    guard let pausedClone, !imageLibrary.isCloningImage else { return }
    do {
      try store.discard()
      self.pausedClone = nil
      activity.append("Discarded the paused clone of \(pausedClone.name).")
    } catch {
      imageLibrary.errorMessage = error.localizedDescription
      activity.append("Could not discard the paused clone: \(error.localizedDescription)")
    }
  }

  func restore(_ paused: PausedClone) throws {
    try store.restore(paused)
  }

  func discardAfterResume() throws {
    try store.discard()
    pausedClone = nil
  }

  func forget() {
    try? store.discard()
    pausedClone = nil
  }

  func removePartialDownload(for request: TartCloneRequest) {
    store.removePartialDownload(for: request)
  }

  // a paused or failed remote download is kept outside tart's tmp folder so it can resume.
  func keepPartialDownload(
    for request: TartCloneRequest,
    progress: TartCloneProgress,
    afterFailure failure: Error?
  ) {
    if failure != nil, !store.hasPartialDownload(for: request) {
      forget()
      return
    }
    do {
      let kept = try store.keep(request, progress: progress)
      pausedClone = kept
      if failure != nil {
        imageLibrary.errorMessage =
          "\(failure?.localizedDescription ?? "") The partial download was kept. Choose Resume to retry."
        activity.append("Kept the partial download of \(request.name)\(progress.percentSuffix).")
      } else if kept.hasPartialDownload {
        activity.append("Paused the clone of \(request.name)\(progress.percentSuffix).")
      } else {
        activity.append("Paused the clone of \(request.name) before any disk data was kept.")
      }
    } catch {
      imageLibrary.errorMessage = error.localizedDescription
      activity.append("Could not keep the partial download: \(error.localizedDescription)")
    }
  }
}
