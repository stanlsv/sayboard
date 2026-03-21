import SwiftUI

// HistoryListView -- List of transcription history records

struct HistoryListView: View {

  // MARK: Internal

  var body: some View {
    self.recordsList
      .overlay {
        if self.records.isEmpty { self.emptyState }
      }
      .onAppear { self.loadRecords() }
      .onChange(of: self.speechService.historySaveGeneration) {
        self.loadRecords()
      }
  }

  // MARK: Private

  @EnvironmentObject private var playerService: AudioPlayerService
  @EnvironmentObject private var speechService: SpeechRecognitionService
  @State private var records = [HistoryRecord]()

  private let store = HistoryStore.shared

  private var emptyState: some View {
    ContentUnavailableView {
      Label {
        Text("No recordings yet")
      } icon: {
        Image("tab-history")
          .resizable()
          .frame(width: 48, height: 48)
      }
    } description: {
      Text("Your transcriptions will appear here.")
    }
  }

  private var privacyHeader: some View {
    HStack(spacing: 10) {
      Image(systemName: "lock.fill")
        .font(.title3)
        .foregroundStyle(.green)
      Text(
        """
        Your voice data never leaves your phone — \
        everything is processed locally by a model you download once. \
        No servers, no tracking, no internet needed, open-source code. \
        Made to keep 100% of your data on your device.
        """
      )
      .font(.subheadline.weight(.medium))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }

  private var recordsList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        if !self.records.isEmpty {
          self.privacyHeader
        }
        ForEach(self.records) { record in
          VStack(spacing: 0) {
            if record.id != self.records.first?.id {
              Divider()
            }
            HistoryRowView(record: record) {
              self.deleteRecord(id: record.id)
            }
            .padding(.horizontal)
            .padding(.vertical, 18)
          }
        }
      }
    }
  }

  private func loadRecords() {
    self.records = self.store.loadRecords()
  }

  private func deleteRecord(id: UUID) {
    self.playerService.stop()
    self.store.deleteRecord(id: id)
    withAnimation(.easeInOut(duration: 0.35)) {
      self.records.removeAll { $0.id == id }
    }
  }

}
