import Foundation

// MARK: - AppSearchResult

struct AppSearchResult: Decodable, Sendable, Identifiable {

  // MARK: Internal

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

  // MARK: Private

  private enum CodingKeys: String, CodingKey {
    case bundleId
    case trackName
    case artworkUrl60
    case artworkUrl100
  }
}

// MARK: - ITunesSearchResponse

private struct ITunesSearchResponse: Decodable {
  let results: [AppSearchResult]
}

// MARK: - SearchPhase

enum SearchPhase: Equatable {
  case idle
  case searching
  case done
}

// MARK: - AppSearchService

// AppSearchService -- iTunes Search API client with debounced search

@MainActor
@Observable
final class AppSearchService {

  // MARK: Internal

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

  // MARK: Private

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
    let urlString = "\(Self.baseURL)?term=\(encoded)&entity=software&limit=\(Self.resultLimit)"
    guard let url = URL(string: urlString) else {
      self.results = []
      self.phase = .done
      return
    }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard !Task.isCancelled else { return }
      let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
      self.results = response.results
    } catch {
      guard !Task.isCancelled else { return }
      self.results = []
    }

    self.phase = .done
  }
}
