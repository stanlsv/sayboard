import SwiftUI

// HistoryRowView -- Single row in the history list

struct HistoryRowView: View {

  // MARK: Internal

  let record: HistoryRecord
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      self.headerRow
      self.transcriptionText
      self.audioPlayerControls
    }
    .padding(.vertical, 4)
  }

  // MARK: Private

  @EnvironmentObject private var playerService: AudioPlayerService
  @State private var isExpanded = false
  @State private var copied = false

  private let truncationThreshold = 150
  private let truncationSuffixReserve = 20

  private var needsTruncation: Bool {
    self.record.transcription.count > self.truncationThreshold
  }

  private var truncatedTranscription: String {
    let targetLength = self.truncationThreshold - self.truncationSuffixReserve
    let prefix = self.record.transcription.prefix(targetLength)
    if let lastSpace = prefix.lastIndex(of: " ") {
      return String(prefix[prefix.startIndex..<lastSpace])
    }
    return String(prefix)
  }

  private var headerRow: some View {
    HStack {
      Text(self.record.date, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      self.copyButton
      self.deleteButton
    }
  }

  @ViewBuilder
  private var transcriptionText: some View {
    if self.record.transcription.isEmpty {
      Text("No transcription")
        .font(.body)
        .foregroundStyle(.tertiary)
        .italic()
    } else if !self.needsTruncation {
      Text(self.record.transcription)
        .font(.body)
    } else if self.isExpanded {
      (Text(self.record.transcription) + Text(" ") + Text("less").foregroundColor(.secondary))
        .font(.body)
        .onTapGesture {
          self.isExpanded = false
        }
    } else {
      (Text(self.truncatedTranscription) + Text("\u{2026} ") + Text("more").foregroundColor(.secondary))
        .font(.body)
        .onTapGesture {
          self.isExpanded = true
        }
    }
  }

  @ViewBuilder
  private var audioPlayerControls: some View {
    if let url = HistoryStore.shared.audioFileURL(for: record.audioFileName) {
      WaveformPlayerView(
        audioURL: url,
        totalDuration: self.record.duration,
        waveformSamples: self.record.waveformSamples,
        playerService: self.playerService,
      )
    }
  }

  private var copyButton: some View {
    Button {
      UIPasteboard.general.string = self.record.transcription
      withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
        self.copied = true
      }
      let delay = 0.75
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
          self.copied = false
        }
      }
    } label: {
      Image(self.copied ? "icon-check" : "icon-copy")
        .resizable()
        .frame(width: 18, height: 18)
        .foregroundStyle(self.copied ? .blue : .secondary)
        .scaleEffect(self.copied ? 1.2 : 1.0)
    }
    .buttonStyle(.plain)
    .disabled(self.record.transcription.isEmpty)
  }

  private var deleteButton: some View {
    Button(role: .destructive) {
      self.onDelete()
    } label: {
      Image("icon-delete")
        .resizable()
        .frame(width: 18, height: 18)
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
  }
}
