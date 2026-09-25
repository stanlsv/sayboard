

struct ModelListSortKey {
  let isActive: Bool
  let isDownloaded: Bool
  let isSupported: Bool
  let isRecommended: Bool
  let catalogRank: Double

  func precedes(_ other: Self) -> Bool {
    if self.isActive != other.isActive { return self.isActive }
    if self.isSupported != other.isSupported { return self.isSupported }
    if self.isDownloaded != other.isDownloaded { return self.isDownloaded }
    if self.isRecommended != other.isRecommended { return self.isRecommended }
    return self.catalogRank > other.catalogRank
  }
}
