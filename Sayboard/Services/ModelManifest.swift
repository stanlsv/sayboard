// ModelManifest -- Fetches and decodes the R2 model manifest

import Foundation

// MARK: - ManifestError

enum ManifestError: LocalizedError {
  case invalidURL
  case networkError(Error)
  case decodingError(Error)

  // MARK: Internal

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

// MARK: - ModelEntry

struct ModelEntry: Decodable, Sendable {
  let url: URL
  let sha256: String
  let sizeBytes: Int64
  let engine: STTEngine
}

// MARK: - LLMModelEntry

struct LLMModelEntry: Decodable, Sendable {
  let url: URL
  let sha256: String
  let sizeBytes: Int64
}

// MARK: - ModelManifest

struct ModelManifest: Decodable, Sendable {

  // MARK: Lifecycle

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.version = try container.decode(Int.self, forKey: .version)
    self.models = try container.decode([String: ModelEntry].self, forKey: .models)
    self.llmModels = try container.decodeIfPresent([String: LLMModelEntry].self, forKey: .llmModels) ?? [:]
  }

  // MARK: Internal

  let version: Int
  let models: [String: ModelEntry]
  let llmModels: [String: LLMModelEntry]

  func entry(for variant: ModelVariant) -> ModelEntry? {
    self.models[variant.rawValue]
  }

  func llmEntry(for variant: LLMModelVariant) -> LLMModelEntry? {
    self.llmModels[variant.rawValue]
  }

  // MARK: Private

  private enum CodingKeys: String, CodingKey {
    case version
    case models
    case llmModels
  }
}

// MARK: - ManifestFetcher

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
