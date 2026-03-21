// LLMBridge -- File-based IPC for LLM text processing between main app and keyboard extension

import Foundation

// MARK: - LLMRequest

struct LLMRequest: Codable, Sendable {
  let text: String
  let action: LLMAction
  let customPromptId: UUID?
  let language: String?
}

// MARK: - LLMBridge

struct LLMBridge: Sendable {

  // MARK: Internal

  static func writeRequest(_ request: LLMRequest) {
    guard let url = requestFileURL else { return }
    do {
      let data = try JSONEncoder().encode(request)
      try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    } catch {
      // no-op
    }
  }

  static func readRequest() -> LLMRequest? {
    guard let url = requestFileURL else { return nil }
    guard let data = try? Data(contentsOf: url) else {
      return nil
    }
    return try? JSONDecoder().decode(LLMRequest.self, from: data)
  }

  static func writeResult(_ text: String) {
    guard let url = resultFileURL else { return }
    do {
      try Data(text.utf8).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    } catch {
      // no-op
    }
  }

  static func readResult() -> String? {
    guard let url = resultFileURL else { return nil }
    return try? String(contentsOf: url, encoding: .utf8)
  }

  static func clearRequest() {
    guard let url = requestFileURL else { return }
    try? FileManager.default.removeItem(at: url)
  }

  static func clearResult() {
    guard let url = resultFileURL else { return }
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: Private

  private static let requestFileName = "llm_request.json"
  private static let resultFileName = "llm_result.txt"

  private static var requestFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent(requestFileName)
  }

  private static var resultFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent(resultFileName)
  }
}
