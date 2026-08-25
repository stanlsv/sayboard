
import SwiftUI

struct TextOutputSection: View {

  var body: some View {
    Section {
      self.writingStyleRow

      AITextProcessingRow(
        llmEnabled: self.llmEnabled,
        hasUsableModel: self.llmDownloadService.hasUsableModel,
        selectedVariantName: self.llmDownloadService.selectedVariant.displayName,
      )

      NavigationLink {
        SnippetsView()
      } label: {
        HStack {
          Text("Snippets")
          Spacer()
          Text(verbatim: "\(self.snippetCount)")
            .foregroundStyle(.secondary)
        }
      }

      Toggle("Auto-Copy to Clipboard", isOn: self.$alsoCopyToClipboard)
    } header: {
      Text("Text")
    } footer: {
      Text(Self.clipboardFooterMessage)
    }
    .onAppear {
      self.snippetCount = self.settings.snippets.count
      self.writingStyle = self.settings.defaultWritingStyle
    }
  }

  private static let clipboardFooterMessage: LocalizedStringKey = "After each dictation, the inserted text is also copied to the system clipboard. Replaces the previous clipboard contents."

  @AppStorage(SharedKey.llmEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
  private var llmEnabled = false
  @AppStorage(SharedKey.alsoCopyToClipboard, store: UserDefaults(suiteName: AppGroup.identifier))
  private var alsoCopyToClipboard = false
  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @State private var settings = SharedSettings()
  @State private var snippetCount = 0
  @State private var showStylePicker = false
  @State private var writingStyle = WritingStyle.formal

  @ViewBuilder
  private var writingStyleRow: some View {
    if OperatingSystem.isHostBundleIdBroken {
      Button {
        self.showStylePicker = true
      } label: {
        HStack {
          Text("Writing Style")
          Spacer()
          Text(LocalizedStringKey(self.writingStyle.displayNameKey))
            .foregroundStyle(.secondary)
          Image(systemName: "chevron.up.chevron.down")
            .imageScale(.small)
            .foregroundStyle(.secondary)
        }
      }
      .foregroundStyle(.primary)
      .sheet(isPresented: self.$showStylePicker) {
        DefaultStylePickerView(selectedStyle: self.writingStyleBinding)
      }
    } else {
      NavigationLink {
        WritingStyleListView()
      } label: {
        Text("Writing Style")
      }
    }
  }

  private var writingStyleBinding: Binding<WritingStyle> {
    Binding(
      get: { self.writingStyle },
      set: { newValue in
        self.writingStyle = newValue
        self.settings.defaultWritingStyle = newValue
      },
    )
  }
}

struct AITextProcessingRow: View {

  let llmEnabled: Bool
  let hasUsableModel: Bool
  let selectedVariantName: String

  var body: some View {
    NavigationLink {
      LLMSettingsView()
    } label: {
      HStack {
        Text("AI Text Processing")
        Spacer()
        if self.llmEnabled, self.hasUsableModel {
          Text(verbatim: self.selectedVariantName)
            .foregroundStyle(.secondary)
        } else {
          Text("Off")
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}
