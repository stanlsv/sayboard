// LLMProcessingCoordinator -- Orchestrates LLM inference: unloads STT, loads LLM, runs inference, writes result

import Foundation

import UIKit

// MARK: - LLMProcessingCoordinator

@MainActor
final class LLMProcessingCoordinator: ObservableObject {

  // MARK: Internal

  let inferenceService = LLMInferenceService()

  weak var speechService: SpeechRecognitionService?
  weak var downloadService: LLMDownloadService?

  @Published private(set) var isProcessing = false

  func setupObservers() {
    self.requestObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.requestLLMProcessing
    ) { [weak self] in
      Task { @MainActor [weak self] in
        let tokenSettings = SharedSettings()
        tokenSettings.synchronize()
        guard tokenSettings.dictationSessionToken != nil else {
          return
        }
        await self?.handleProcessingRequest()
      }
    }
  }

  // MARK: Private

  private struct ValidatedRequest {
    let request: LLMRequest
    let modelPath: String
    let variant: LLMModelVariant
  }

  private static let safetyMarginSeconds: TimeInterval = 5
  private static let inferenceTimeoutSeconds: TimeInterval = 120

  private var requestObserver: DarwinNotificationObserver?

  private func handleProcessingRequest() async {
    guard !self.isProcessing else {
      return
    }

    self.isProcessing = true
    let settings = SharedSettings()
    settings.isLLMProcessing = true
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingStarted)

    defer {
      self.isProcessing = false
      settings.isLLMProcessing = false
      LLMBridge.clearRequest()
    }

    guard let validated = self.validateRequest(settings: settings) else { return }

    let bgTaskID = self.beginInferenceBackgroundTask()
    defer { self.endInferenceBackgroundTask(bgTaskID) }

    await self.prepareForInference(variant: validated.variant, modelPath: validated.modelPath)

    guard self.inferenceService.loadState == .loaded else {
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingFailed)
      return
    }

    let systemPrompt = self.buildSystemPrompt(for: validated.request, settings: settings)
    let result = await self.runInferenceWithTimeout(systemPrompt: systemPrompt, userText: validated.request.text)

    if let result, !result.isEmpty {
      let finalResult: String
      if validated.request.action == .addPunctuation || validated.request.action == .fixGrammar {
        finalResult = result
      } else {
        let store = AppStyleStore()
        let hostId = settings.hostBundleId
        let resolvedStyle = hostId.flatMap { store.style(for: $0) } ?? settings.defaultWritingStyle
        finalResult = TextStyleFormatter.format(result, style: resolvedStyle)
      }
      LLMBridge.writeResult(finalResult)
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingComplete)
    } else {
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingFailed)
    }

    self.inferenceService.unloadModel()
  }

  private func validateRequest(settings: SharedSettings) -> ValidatedRequest? {
    settings.synchronize()
    guard let request = LLMBridge.readRequest() else {
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingFailed)
      return nil
    }

    guard let downloadService = self.downloadService, downloadService.hasUsableModel else {
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingFailed)
      return nil
    }

    let variant = settings.selectedLLMVariant
    guard let modelPath = downloadService.modelFileURL(for: variant)?.path else {
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.llmProcessingFailed)
      return nil
    }

    return ValidatedRequest(request: request, modelPath: modelPath, variant: variant)
  }

  private func beginInferenceBackgroundTask() -> UIBackgroundTaskIdentifier {
    var bgTaskID = UIBackgroundTaskIdentifier.invalid
    bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "LLMInference") {
      UIApplication.shared.endBackgroundTask(bgTaskID)
      bgTaskID = .invalid
    }
    return bgTaskID
  }

  private func endInferenceBackgroundTask(_ taskID: UIBackgroundTaskIdentifier) {
    if taskID != .invalid {
      UIApplication.shared.endBackgroundTask(taskID)
    }
  }

  private func prepareForInference(variant: LLMModelVariant, modelPath: String) async {
    if let speechService = self.speechService {
      await speechService.unloadForLLMProcessing()
    }

    if self.inferenceService.loadState != .loaded {
      await self.inferenceService.loadModel(variant: variant, path: modelPath)
    }
  }

  private func buildSystemPrompt(for request: LLMRequest, settings: SharedSettings) -> String {
    let language = request.language
    if
      let customId = request.customPromptId,
      let custom = settings.llmCustomPrompts.first(where: { $0.id == customId })
    {
      return LLMPromptTemplates.systemPrompt(for: custom, language: language)
    }
    return LLMPromptTemplates.systemPrompt(for: request.action, language: language)
  }

  private func runInferenceWithTimeout(systemPrompt: String, userText: String) async -> String? {
    // Check background time remaining
    let remaining = UIApplication.shared.backgroundTimeRemaining
    let timeout: TimeInterval =
      if remaining < .greatestFiniteMagnitude {
        max(remaining - Self.safetyMarginSeconds, 10)
      } else {
        Self.inferenceTimeoutSeconds
      }

    return await withTaskGroup(of: String?.self) { group in
      group.addTask {
        await self.inferenceService.process(systemPrompt: systemPrompt, userText: userText)
      }

      group.addTask {
        try? await Task.sleep(for: .seconds(timeout))
        return nil
      }

      // Return first non-nil result, or nil on timeout
      if let result = await group.next() {
        group.cancelAll()
        return result
      }

      group.cancelAll()
      return nil
    }
  }
}
