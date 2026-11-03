import SwiftUI

struct ImagesView: View {
  @Environment(AppModel.self) private var model
  @State private var clonePresentation: ClonePresentation?
  @State private var pendingDeletion: TartImage?
  @State private var cloneConfirmation: CloneConfirmation?
  @State private var updateTarget: ImageUpdateTarget?
  // visual row selection, kept separate from the golden designation so selecting a
  // row never triggers provisioning.
  @State private var selection: String?

  var body: some View {
    @Bindable var model = model

    VStack(spacing: 0) {
      if model.images.isEmpty && !model.isRefreshingImages {
        ImagesEmptyView(canStartClone: canStartClone) {
          clonePresentation = ClonePresentation()
        }
        .frame(maxHeight: .infinity)
      } else {
        ImageList(
          selection: $selection,
          provisioningDisabled: provisioningDisabled,
          onDelete: { pendingDeletion = $0 },
          onUpdate: { updateTarget = $0 }
        )
      }

      CloneStatusSection { cloneConfirmation = $0 }

      if model.showsOperationLogs {
        Divider()
        OperationLogsPanel(title: outputTitle, output: model.operationOutput)
      }

      if let error = model.imageErrorMessage {
        Divider()
        ImageErrorBar(message: error) { model.imageErrorMessage = nil }
      }
    }
    .navigationTitle("Images")
    .navigationSubtitle(subtitle)
    .toolbar {
      ImagesToolbar(
        canStartClone: canStartClone,
        provisioningDisabled: provisioningDisabled,
        selectedImage: selectedImage,
        onClone: { clonePresentation = ClonePresentation() },
        onDelete: { pendingDeletion = $0 }
      )
    }
    .safeAreaInset(edge: .bottom) {
      TartHomeBar(path: model.paths.tartHome.path) { model.revealTartHome() }
    }
    .sheet(item: $clonePresentation) { _ in
      CloneImageView()
        .environment(model)
    }
    .sheet(item: $updateTarget) { target in
      UpdateImageView(target: target)
        .environment(model)
    }
    .task(id: updateCheckKey) { await model.checkForImageUpdates() }
    .sheet(item: $model.pendingGoldenPrompt) { prompt in
      GoldenImagePromptView(prompt: prompt)
        .environment(model)
    }
    .alert("Delete image?", isPresented: deletionBinding, presenting: pendingDeletion) {
      image in
      Button("Delete", role: .destructive) {
        Task { await model.deleteImage(image) }
      }
      Button("Cancel", role: .cancel) {}
    } message: { image in
      Text("\(image.name) will be permanently deleted from this Mac.")
    }
    .modifier(CloneConfirmationAlert(confirmation: $cloneConfirmation))
  }

  private var subtitle: String {
    // session vms only count what they wrote, the rest of their disk is shared.
    let images = model.images.filter { model.writtenBytes[$0.name] == nil }
    let written = model.writtenBytes.values.reduce(0, +)
    let total = images.reduce(Int64(0)) { $0 + Int64($1.allocatedSizeGB) * 1_000_000_000 }
    let count = images.count
    let size = ByteCountFormatter.string(fromByteCount: total + written, countStyle: .file)
    return "\(count) image\(count == 1 ? "" : "s"), \(size) on disk"
  }

  // session vms come and go with every job, only the images and their origins matter.
  private var updateCheckKey: [String] {
    model.images.filter { !$0.name.hasPrefix(VMName.controllerPrefix) }.map {
      "\($0.name)@\(model.preferences.origin(of: $0.name)?.digest ?? "")"
    }
  }

  private var canStartClone: Bool {
    !model.isImageOperationRunning && !model.coordinator.isRunning && model.pausedClone == nil
  }

  private var outputTitle: String {
    if model.isProvisioningImage { return "Provisioning logs" }
    if model.isCloningImage { return "Clone logs" }
    return "Last operation logs"
  }

  private var provisioningDisabled: Bool {
    model.isImageOperationRunning || model.coordinator.isRunning
  }

  private var selectedImage: TartImage? {
    model.images.first { $0.name == selection }
  }

  private var deletionBinding: Binding<Bool> {
    Binding(
      get: { pendingDeletion != nil },
      set: { if !$0 { pendingDeletion = nil } }
    )
  }
}
