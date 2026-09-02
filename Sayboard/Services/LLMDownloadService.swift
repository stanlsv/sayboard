
import Combine
import Foundation

@MainActor
final class LLMDownloadService: ObservableObject {

  init() {
    LLMModelStorageManager.removeOrphanedDirectories()
    self.verifyExistingModels()
    self.subscribeToDownloadEvents()
    self.startUpgradeIfNeeded()
  }

  @Published var variantStates = [LLMModelVariant: ModelDownloadState]()
  @Published var selectedVariant: LLMModelVariant = SharedSettings().selectedLLMVariant

  @Published var didEnableByDownload = false

  var hasUsableModel: Bool {
    self.isDownloaded(SharedSettings().selectedLLMVariant)
  }

  var replacedByUpgrade: LLMModelVariant? {
    guard let replaced = SharedSettings().completedLLMUpgradeFrom else { return nil }
    guard self.isDownloaded(replaced) else {
      SharedSettings().completedLLMUpgradeFrom = nil
      return nil
    }
    return replaced
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
      } else if self.isDownloadInFlight(variant) {
        self.variantStates[variant] = .downloading(progress: 0)
      } else {
        self.variantStates[variant] = .notDownloaded
      }
    }
    self.ensureValidSelection()
    self.syncHasUsableModel()
  }

  func startDownload(variant: LLMModelVariant) {
    guard !self.isDownloadInFlight(variant) else { return }

    self.variantStates[variant] = .downloading(progress: 0)
    self.addVariantToPersistence(variant)

    self.enqueueTasks[variant] = Task {
      await self.enqueueDownload(variant: variant)
    }
  }

  func cancelDownload(variant: LLMModelVariant) {
    self.recordUpgradeDecline(for: variant)
    self.enqueueTasks[variant]?.cancel()
    self.enqueueTasks[variant] = nil

    for type in Self.llmDownloadTypes {
      BackgroundDownloadManager.shared.cancelDownload(
        variantRawValue: variant.rawValue,
        downloadType: type,
      )
    }

    try? LLMModelStorageManager.delete(variant)
    self.variantStates[variant] = .notDownloaded
    self.removeVariantFromPersistence(variant)
  }

  func deleteModel(variant: LLMModelVariant) {
    self.recordUpgradeDecline(for: variant)
    do {
      try LLMModelStorageManager.delete(variant)
    } catch { }

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
    if !self.hasUsableModel {
      settings.llmEnabled = false
    }
  }

  func dismissError(variant: LLMModelVariant) {
    self.variantStates[variant] = .notDownloaded
  }

  func dismissUpgradeNotice() {
    SharedSettings().completedLLMUpgradeFrom = nil
    self.objectWillChange.send()
  }

  func revertUpgrade() {
    guard let replaced = self.replacedByUpgrade else { return }
    if let successor = replaced.successor {
      let settings = SharedSettings()
      settings.declinedLLMUpgrades.insert(successor)
    }
    self.selectVariant(replaced)
    self.dismissUpgradeNotice()
  }

  func deleteReplacedModel() {
    guard let replaced = self.replacedByUpgrade else { return }
    self.deleteModel(variant: replaced)
    self.dismissUpgradeNotice()
  }

  func syncHasUsableModel() {
    let usable = self.hasUsableModel
    SharedSettings().hasUsableLLMModel = usable
  }

  func checkForInterruptedDownloadOnLaunch() {
    let settings = SharedSettings()
    let interrupted = settings.llmDownloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    let message: LocalizedStringResource = "Download was interrupted. Tap Retry to continue."
    for variant in interrupted {
      guard self.state(for: variant) != .downloaded else {
        self.removeVariantFromPersistence(variant)
        continue
      }
      if self.isDownloadInFlight(variant) {
        continue
      }
      try? LLMModelStorageManager.delete(variant)
      self.variantStates[variant] = .error(message: message)
      self.removeVariantFromPersistence(variant)
    }
  }

  func resumeInterruptedDownloadIfNeeded() {
    let settings = SharedSettings()
    let interrupted = settings.llmDownloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    for variant in interrupted {
      if self.isDownloadInFlight(variant) {
        continue
      }
      self.removeVariantFromPersistence(variant)
      self.startDownload(variant: variant)
    }
  }

  private static let llmDownloadTypes: [DownloadType] = [.llm, .llmUpgrade]

  private var cachedManifest: ModelManifest?
  private var eventCancellable: AnyCancellable?
  private var enqueueTasks = [LLMModelVariant: Task<Void, Never>]()

  private func subscribeToDownloadEvents() {
    self.eventCancellable = BackgroundDownloadManager.shared.eventSubject
      .filter { event in
        switch event {
        case .progress(let type, _, _), .completed(let type, _, _), .failed(let type, _, _):
          type == .llm || type == .llmUpgrade
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

    case .completed(let type, let variantRawValue, _):
      guard let variant = LLMModelVariant(rawValue: variantRawValue) else { return }
      self.enqueueTasks[variant] = nil
      self.variantStates[variant] = .downloaded
      self.removeVariantFromPersistence(variant)
      if type == .llmUpgrade {
        self.completeUpgrade(to: variant)
      } else {
        self.autoSelectIfNeeded(variant: variant)
        self.enableProcessingAfterDownload(variant: variant)
      }

    case .failed(_, let variantRawValue, let error):
      guard let variant = LLMModelVariant(rawValue: variantRawValue) else { return }
      self.enqueueTasks[variant] = nil
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
    }
  }

  private func enqueueDownload(variant: LLMModelVariant, downloadType: DownloadType = .llm) async {
    do {
      let manifest = try await self.fetchManifest()
      guard let entry = manifest.llmEntry(for: variant) else {
        throw R2DownloadError.manifestMissingVariant(variant.rawValue)
      }
      guard entry.isLoadableByThisBuild else {
        DiagnosticLog.write("llm: \(variant.rawValue) needs llama.cpp > \(LlamaRuntime.buildNumber)")
        throw R2DownloadError.appTooOldForModel
      }

      let peakRequired = ModelDiskReserve.requiredBytes(peak: entry.peakDiskBytes)
      let settledRequired = downloadType == .llmUpgrade
        ? entry.sizeBytes + ModelDiskReserve.unattendedFloorBytes
        : 0
      let requiredBytes = max(peakRequired, settledRequired)
      if let available = ModelDiskReserve.availableBytes(), available < requiredBytes {
        throw R2DownloadError.insufficientDiskSpace
      }

      try LLMModelStorageManager.ensureRootExists()
      let destDir = LLMModelStorageManager.directory(for: variant)

      let metadata = DownloadMetadata(
        downloadType: downloadType,
        variantRawValue: variant.rawValue,
        expectedSHA256: entry.sha256,
        sourceURL: entry.url,
        destinationDirectory: destDir,
        sizeBytes: entry.sizeBytes,
      )

      BackgroundDownloadManager.shared.enqueueDownload(metadata: metadata)
    } catch {
      if downloadType == .llmUpgrade, case R2DownloadError.insufficientDiskSpace = error {
        self.variantStates[variant] = .notDownloaded
        self.removeVariantFromPersistence(variant)
        return
      }
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
    }
  }

  private func recordUpgradeDecline(for variant: LLMModelVariant) {
    guard let predecessor = LLMModelVariant.allCases.first(where: { $0.successor == variant }) else { return }
    guard self.isDownloaded(predecessor) else { return }
    let settings = SharedSettings()
    settings.declinedLLMUpgrades.insert(variant)
  }

  private func startUpgradeIfNeeded() {
    let settings = SharedSettings()
    let current = settings.selectedLLMVariant

    guard self.isDownloaded(current), let successor = current.successor else { return }
    guard !self.isDownloaded(successor) else { return }
    guard !settings.declinedLLMUpgrades.contains(successor) else { return }
    guard successor.isSupportedOnCurrentDevice else {
      return
    }
    guard !self.isDownloadInFlight(successor) else { return }
    if case .downloading = self.state(for: successor) { return }

    self.variantStates[successor] = .downloading(progress: 0)
    self.enqueueTasks[successor] = Task {
      await self.enqueueDownload(variant: successor, downloadType: .llmUpgrade)
    }
  }

  private func completeUpgrade(to successor: LLMModelVariant) {
    let settings = SharedSettings()
    guard
      let replaced = LLMModelVariant.allCases.first(where: { $0.successor == successor }),
      settings.selectedLLMVariant == replaced
    else {
      self.syncHasUsableModel()
      return
    }

    settings.selectedLLMVariant = successor
    self.selectedVariant = successor
    settings.completedLLMUpgradeFrom = replaced
    self.syncHasUsableModel()
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

  private func enableProcessingAfterDownload(variant _: LLMModelVariant) {
    let settings = SharedSettings()
    guard !settings.llmEnabled else { return }
    settings.llmEnabled = true
    self.didEnableByDownload = true
  }

  private func isDownloadInFlight(_ variant: LLMModelVariant) -> Bool {
    Self.llmDownloadTypes.contains { type in
      BackgroundDownloadManager.shared.hasActiveDownload(
        variantRawValue: variant.rawValue,
        downloadType: type,
      )
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
