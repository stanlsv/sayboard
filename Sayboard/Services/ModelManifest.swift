
import Foundation

enum ManifestError: LocalizedError {
  case invalidURL
  case networkError(Error)
  case decodingError(Error)

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      "Invalid manifest URL"
    case .networkError(let error):
      "Network error fetching manifest: \(error.localizedDescription)"
    case .decodingError(let error):
      "Failed to decode manifest: \(error.localizedDescription)"
    }
  }
}

struct ModelEntry: Decodable, Sendable {
  let url: URL
  let sha256: String
  let sizeBytes: Int64
  let expandedBytes: Int64?
  let engine: STTEngine

  var peakDiskBytes: Int64 {
    guard let expandedBytes else {
      return Int64(Double(self.sizeBytes) * ModelDiskReserve.unmeasuredSpeechMultiplier)
    }
    return self.sizeBytes + expandedBytes
  }
}

struct LLMModelEntry: Decodable, Sendable {
  let url: URL
  let sha256: String
  let sizeBytes: Int64
  let minLlamaBuild: Int?
  let expandedBytes: Int64?

  var isLoadableByThisBuild: Bool {
    guard let minLlamaBuild else { return true }
    return LlamaRuntime.buildNumber >= minLlamaBuild
  }

  var peakDiskBytes: Int64 {
    guard let expandedBytes else {
      return self.sizeBytes * 2
    }
    return self.sizeBytes + expandedBytes
  }
}

struct ModelManifest: Decodable, Sendable {

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.version = try container.decode(Int.self, forKey: .version)
    self.models = try container.decode([String: ModelEntry].self, forKey: .models)
    self.llmModels = try container.decodeIfPresent([String: LLMModelEntry].self, forKey: .llmModels) ?? [:]
  }

  let version: Int
  let models: [String: ModelEntry]
  let llmModels: [String: LLMModelEntry]

  func entry(for variant: ModelVariant) -> ModelEntry? {
    self.models[variant.rawValue]
  }

  func llmEntry(for variant: LLMModelVariant) -> LLMModelEntry? {
    self.llmModels[variant.rawValue]
  }

  private enum CodingKeys: String, CodingKey {
    case version
    case models
    case llmModels
  }
}

enum ManifestFetcher {

  static func fetch() async throws -> ModelManifest {
    guard let url = URL(string: ModelServer.manifestURL) else {
      throw ManifestError.invalidURL
    }

    let data: Data
    do {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalCacheData
      let (responseData, _) = try await URLSession.shared.data(for: request)
      data = responseData
    } catch {
      throw ManifestError.networkError(error)
    }

    do {
      return try JSONDecoder().decode(ModelManifest.self, from: data)
    } catch {
      throw ManifestError.decodingError(error)
    }
  }
}
