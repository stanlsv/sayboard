// LLMDownloadService -- Downloads LLM GGUF models on demand via background URLSession

import Combine
import Foundation

import UIKit

// MARK: - LLMDownloadService

@MainActor
final class LLMDownloadService: ObservableObject {

  // MARK: Lifecycle

  init() {
    self.verifyExistingModels()
    self.subscribeToDownloadEvents()
  }

  // MARK: Internal

  @Published var variantStates = [LLMModelVariant: ModelDownloadState]()
  @Published var selectedVariant: LLMModelVariant = SharedSettings().selectedLLMVariant

  var hasUsableModel: Bool {
    self.isDownloaded(SharedSettings().selectedLLMVariant)
  }

  func state(for variant: LLMModelVariant) -> ModelDownloadState {
    self.variantStates[variant] ?? .notDownloaded
  }

  func isDownloaded(_ variant: LLMModelVariant) -> Bool {
    self.state(for: variant) == .downloaded
  }

  func selectVariant(_ variant: LLMModelVariant) {
    SharedSettings().selectedLLMVariant = variant
    self.selectedVariant = variant
    self.syncHasUsableModel()
  }

  func modelFileURL(for variant: LLMModelVariant) -> URL? {
    LLMModelStorageManager.modelFileURL(for: variant)
  }

  func verifyExistingModels() {
    for variant in LLMModelVariant.allCases {
      switch self.variantStates[variant] {
      case .downloading, .error:
        continue
      case .downloaded, .notDownloaded, .none:
        break
      }
      if LLMModelStorageManager.isDownloaded(variant) {
        self.variantStates[variant] = .downloaded
      } else {
        self.variantStates[variant] = .notDownloaded
      }
    }
    self.ensureValidSelection()
    self.syncHasUsableModel()
  }

  func startDownload(variant: LLMModelVariant) {
    guard
      !BackgroundDownloadManager.shared.hasActiveDownload(
        variantRawValue: variant.rawValue,
        downloadType: .llm,
      )
    else { return }

    guard self.hasEnoughDiskSpace(for: variant) else {
      self.variantStates[variant] = .error(
        message: String(localized: "Not enough storage space. Free up space and try again.")
      )
      return
    }

    UIApplication.shared.isIdleTimerDisabled = true
    self.variantStates[variant] = .downloading(progress: 0)
    self.addVariantToPersistence(variant)

    self.enqueueTask = Task {
      await self.enqueueDownload(variant: variant)
    }
  }

  func cancelDownload(variant: LLMModelVariant) {
    self.enqueueTask?.cancel()
    self.enqueueTask = nil

    BackgroundDownloadManager.shared.cancelDownload(
      variantRawValue: variant.rawValue,
      downloadType: .llm,
    )

    try? LLMModelStorageManager.delete(variant)
    self.variantStates[variant] = .notDownloaded
    self.removeVariantFromPersistence(variant)
  }

  func deleteModel(variant: LLMModelVariant) {
    do {
      try LLMModelStorageManager.delete(variant)
    } catch {
      // no-op
    }

    self.variantStates[variant] = .notDownloaded

    let settings = SharedSettings()
    if settings.selectedLLMVariant == variant {
      let otherDownloaded = LLMModelVariant.allCases.first {
        $0 != variant && self.isDownloaded($0)
      }
      if let other = otherDownloaded {
        settings.selectedLLMVariant = other
        self.selectedVariant = other
      }
    }
    self.syncHasUsableModel()
  }

  func dismissError(variant: LLMModelVariant) {
    self.variantStates[variant] = .notDownloaded
  }

  func syncHasUsableModel() {
    let usable = self.hasUsableModel
    SharedSettings().hasUsableLLMModel = usable
  }

  /// Called on cold launch -- shows error for downloads interrupted by app termination.
  func checkForInterruptedDownloadOnLaunch() {
    let settings = SharedSettings()
    let interrupted = settings.llmDownloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    let message = String(localized: "Download was interrupted. Tap Retry to continue.")
    for variant in interrupted {
      guard self.state(for: variant) != .downloaded else {
        self.removeVariantFromPersistence(variant)
        continue
      }
      // Skip if BackgroundDownloadManager still has an active task
      if
        BackgroundDownloadManager.shared.hasActiveDownload(
          variantRawValue: variant.rawValue,
          downloadType: .llm,
        )
      {
        continue
      }
      try? LLMModelStorageManager.delete(variant)
      self.variantStates[variant] = .error(message: message)
      self.removeVariantFromPersistence(variant)
    }
  }

  /// Called on `ScenePhase.active` -- checks if background downloads are still active.
  func resumeInterruptedDownloadIfNeeded() {
    let settings = SharedSettings()
    let interrupted = settings.llmDownloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    for variant in interrupted {
      if
        BackgroundDownloadManager.shared.hasActiveDownload(
          variantRawValue: variant.rawValue,
          downloadType: .llm,
        )
      {
        continue
      }
      self.removeVariantFromPersistence(variant)
      self.startDownload(variant: variant)
    }
  }

  // MARK: Private

  private static let diskSpaceSafetyMultiplier = 1.5

  private var cachedManifest: ModelManifest?
  private var eventCancellable: AnyCancellable?
  private var enqueueTask: Task<Void, Never>?

  private func subscribeToDownloadEvents() {
    self.eventCancellable = BackgroundDownloadManager.shared.eventSubject
      .filter { event in
        switch event {
        case .progress(let type, _, _): type == .llm
        case .completed(let type, _, _): type == .llm
        case .failed(let type, _, _): type == .llm
        }
      }
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        self?.handleDownloadEvent(event)
      }
  }

  private func handleDownloadEvent(_ event: DownloadEvent) {
    switch event {
    case .progress(_, let variantRawValue, let fraction):
      guard let variant = LLMModelVariant(rawValue: variantRawValue) else { return }
      let capped = min(fraction, ModelDownloadService.downloadProgressCeiling)
      self.variantStates[variant] = .downloading(progress: capped)

    case .completed(_, let variantRawValue, _):
      guard let variant = LLMModelVariant(rawValue: variantRawValue) else { return }
      self.variantStates[variant] = .downloaded
      self.removeVariantFromPersistence(variant)
      self.autoSelectIfNeeded(variant: variant)
      UIApplication.shared.isIdleTimerDisabled = false

    case .failed(_, let variantRawValue, let error):
      guard let variant = LLMModelVariant(rawValue: variantRawValue) else { return }
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }

  /// Fetches manifest and enqueues the download via BackgroundDownloadManager.
  private func enqueueDownload(variant: LLMModelVariant) async {
    do {
      let manifest = try await self.fetchManifest()
      guard let entry = manifest.llmEntry(for: variant) else {
        throw R2DownloadError.manifestMissingVariant(variant.rawValue)
      }

      try LLMModelStorageManager.ensureRootExists()
      let destDir = LLMModelStorageManager.directory(for: variant)

      let metadata = DownloadMetadata(
        downloadType: .llm,
        variantRawValue: variant.rawValue,
        expectedSHA256: entry.sha256,
        sourceURL: entry.url,
        destinationDirectory: destDir,
        sizeBytes: entry.sizeBytes,
      )

      BackgroundDownloadManager.shared.enqueueDownload(metadata: metadata)
    } catch {
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
    }
  }

  private func ensureValidSelection() {
    let settings = SharedSettings()
    let current = settings.selectedLLMVariant
    guard !self.isDownloaded(current) else {
      self.selectedVariant = current
      return
    }
    if let downloaded = LLMModelVariant.allCases.first(where: { isDownloaded($0) }) {
      settings.selectedLLMVariant = downloaded
      self.selectedVariant = downloaded
    }
  }

  private func fetchManifest() async throws -> ModelManifest {
    if let cached = self.cachedManifest {
      return cached
    }
    let manifest = try await ManifestFetcher.fetch()
    self.cachedManifest = manifest
    return manifest
  }

  private func autoSelectIfNeeded(variant: LLMModelVariant) {
    let settings = SharedSettings()
    if !self.isDownloaded(settings.selectedLLMVariant) {
      settings.selectedLLMVariant = variant
      self.selectedVariant = variant
    }
    self.syncHasUsableModel()
  }

  private func hasEnoughDiskSpace(for variant: LLMModelVariant) -> Bool {
    let requiredBytes = Int64(Double(variant.downloadSizeMB) * Self.diskSpaceSafetyMultiplier * 1_000_000)
    do {
      let appSupportURL = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false,
      )
      let values = try appSupportURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      guard let available = values.volumeAvailableCapacityForImportantUsage else { return true }
      return available >= requiredBytes
    } catch {
      return true
    }
  }

  private func addVariantToPersistence(_ variant: LLMModelVariant) {
    let settings = SharedSettings()
    var variants = settings.llmDownloadInProgressVariants
    variants.insert(variant)
    settings.llmDownloadInProgressVariants = variants
  }

  private func removeVariantFromPersistence(_ variant: LLMModelVariant) {
    let settings = SharedSettings()
    var variants = settings.llmDownloadInProgressVariants
    variants.remove(variant)
    settings.llmDownloadInProgressVariants = variants
  }
}
