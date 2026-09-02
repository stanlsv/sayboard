import Foundation

struct AppSearchResult: Decodable, Sendable, Identifiable {

  let bundleId: String
  let trackName: String
  let artworkUrl60: String?
  let artworkUrl100: String?

  var id: String {
    self.bundleId
  }

  var iconURL: URL? {
    (self.artworkUrl100 ?? self.artworkUrl60).flatMap { URL(string: $0) }
  }

  private enum CodingKeys: String, CodingKey {
    case bundleId
    case trackName
    case artworkUrl60
    case artworkUrl100
  }
}

private struct ITunesSearchResponse: Decodable {
  let results: [AppSearchResult]
}

enum SearchPhase: Equatable {
  case idle
  case searching
  case done
}

@MainActor
@Observable
final class AppSearchService {

  private(set) var results = [AppSearchResult]()
  private(set) var phase = SearchPhase.idle
  private(set) var searchId = 0

  func search(query: String) {
    self.searchTask?.cancel()

    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      self.results = []
      self.phase = .idle
      return
    }

    self.searchId += 1
    self.phase = .searching
    self.searchTask = Task {
      await self.performSearch(trimmed: trimmed)
    }
  }

  private static let baseURL = "https://itunes.apple.com/search"
  private static let debounceMilliseconds = 400
  private static let resultLimit = 15

  private var searchTask: Task<Void, Never>?

  private func performSearch(trimmed: String) async {
    do {
      try await Task.sleep(for: .milliseconds(Self.debounceMilliseconds))
    } catch {
      return
    }

    let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
    let found: [AppSearchResult]
    do {
      found = try await self.fetchResults(encoded: encoded, country: Locale.current.region?.identifier)
    } catch {
      found = (try? await self.fetchResults(encoded: encoded, country: nil)) ?? []
    }

    guard !Task.isCancelled else { return }
    self.results = found
    self.phase = .done
  }

  private func fetchResults(encoded: String, country: String?) async throws -> [AppSearchResult] {
    var urlString = "\(Self.baseURL)?term=\(encoded)&entity=software&limit=\(Self.resultLimit)"
    if let country {
      urlString += "&country=\(country)"
    }
    guard let url = URL(string: urlString) else { throw URLError(.badURL) }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return try JSONDecoder().decode(ITunesSearchResponse.self, from: data).results
  }
}
