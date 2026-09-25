import Foundation

enum SpeechModelRecommendation {

  static func speechCode(forIdentifier identifier: String) -> String? {
    guard let base = Locale(identifier: identifier).language.languageCode?.identifier else { return nil }
    let code = self.whisperAliases[base] ?? base
    return SpeechLanguages.all.contains(code) ? code : nil
  }

  static func speechCodes(from identifiers: [String]) -> [String] {
    var seen = Set<String>()
    return identifiers.compactMap(self.speechCode(forIdentifier:)).filter { seen.insert($0).inserted }
  }

  static func recommendedVariant(
    languages: [String],
    isSupported: (ModelVariant) -> Bool = { $0.isSupportedOnCurrentDevice },
  ) -> ModelVariant {
    if self.wanted(languages).isSubset(of: SpeechLanguages.parakeetV3), isSupported(.parakeetV3) {
      return .parakeetV3
    }
    return self.whisperFallbacks.first(where: isSupported) ?? .whisperTiny
  }

  static func alternatives(
    languages: [String],
    excluding recommended: ModelVariant,
    isSupported: (ModelVariant) -> Bool = { $0.isSupportedOnCurrentDevice },
  ) -> [ModelVariant] {
    let wanted = self.wanted(languages)
    let candidates = ModelVariant.allCases.filter { variant in
      variant != recommended && isSupported(variant) && wanted.isSubset(of: variant.supportedLanguages)
    }
    return Array(candidates.sorted { $0.catalogRank > $1.catalogRank }.prefix(self.alternativesLimit))
  }

  static func preferredLanguages(for variant: ModelVariant, from languages: [String]) -> Set<String> {
    guard variant.supportsLanguageSelection else { return [] }
    return Set(languages).intersection(variant.supportedLanguages)
  }

  private static let whisperAliases = ["nb": "no", "jv": "jw", "fil": "tl"]
  private static let whisperFallbacks: [ModelVariant] = [.whisperSmall, .whisperBase, .whisperTiny]
  private static let alternativesLimit = 3

  private static func wanted(_ languages: [String]) -> Set<String> {
    languages.isEmpty ? SpeechLanguages.all : Set(languages)
  }
}
