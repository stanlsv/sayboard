import SwiftUI
import UIKit

// MARK: - RetentionPolicyListView

private struct RetentionPolicyListView: View {

  // MARK: Internal

  @Binding var selected: HistoryRetentionPolicy

  var body: some View {
    List {
      ForEach(HistoryRetentionPolicy.allCases, id: \.self) { policy in
        self.policyRow(for: policy)
      }
    }
    .navigationTitle("Keep History")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var pendingPolicy: HistoryRetentionPolicy?
  @State private var deletionCount = 0

  private func policyRow(for policy: HistoryRetentionPolicy) -> some View {
    Button {
      guard policy != self.selected else {
        self.dismiss()
        return
      }
      let count = HistoryStore.shared.recordsToDeleteCount(for: policy)
      if count > 0 {
        self.deletionCount = count
        self.pendingPolicy = policy
      } else {
        self.selected = policy
        self.dismiss()
      }
    } label: {
      HStack {
        Text(LocalizedStringKey(policy.displayNameKey))
        Spacer()
        if self.selected == policy {
          Image(systemName: "checkmark")
            .foregroundStyle(Color.accentColor)
            .fontWeight(.semibold)
        }
      }
    }
    .foregroundStyle(.primary)
    .confirmationDialog(
      "Delete Recordings",
      isPresented: self.isConfirmationPresented(for: policy),
      titleVisibility: .visible,
    ) {
      Button("Delete \(self.deletionCount)", role: .destructive) {
        self.selected = policy
        self.dismiss()
      }
    } message: {
      Text("This will permanently delete \(self.deletionCount) recordings and their audio files.")
    }
  }

  private func isConfirmationPresented(for policy: HistoryRetentionPolicy) -> Binding<Bool> {
    Binding(
      get: { self.pendingPolicy == policy },
      set: { if !$0 { self.pendingPolicy = nil } },
    )
  }
}

// MARK: - SettingsView

struct SettingsView: View {

  // MARK: Lifecycle

  init() {
    let shared = SharedSettings()
    _selectedRetentionPolicy = State(initialValue: shared.retentionPolicy)
    _selectedAutoStopPolicy = State(initialValue: shared.sessionAutoStopPolicy)
  }

  // MARK: Internal

  var body: some View {
    Form {
      if self.needsSetup {
        self.setupSection
      }
      if self.speechService.isSessionActive {
        SessionInfoView()
      }
      self.sessionSection
      self.historySection
      self.textOutputSection
      self.aboutSection
    }
    .sensoryFeedback(.success, trigger: self.historyClearedTrigger)
    .sensoryFeedback(.success, trigger: self.cacheClearedTrigger)
    .navigationTitle("Settings")
    .onAppear {
      self.refreshHistoryInfo()
      self.snippetCount = self.settings.snippets.count
    }
    .onChange(of: self.selectedRetentionPolicy) { _, newValue in
      self.settings.retentionPolicy = newValue
      HistoryStore.shared.applyRetentionPolicy()
      self.refreshHistoryInfo()
    }
    .onChange(of: self.selectedAutoStopPolicy) { _, newValue in
      self.settings.sessionAutoStopPolicy = newValue
      if self.speechService.isSessionActive {
        self.speechService.session.updateTimeout()
      }
    }
  }

  // MARK: Private

  private static let defaultLanguage = AppLanguageConfig.fallback

  @AppStorage(SharedKey.appLanguage) private var selectedAppLanguage = defaultLanguage
  @AppStorage(SharedKey.llmEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
  private var llmEnabled = false
  @Environment(\.locale) private var locale
  @EnvironmentObject private var speechService: SpeechRecognitionService
  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var downloadService: ModelDownloadService
  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @State private var settings = SharedSettings()
  @State private var selectedRetentionPolicy: HistoryRetentionPolicy
  @State private var selectedAutoStopPolicy: SessionAutoStopPolicy
  @State private var showClearHistoryConfirmation = false
  @State private var showClearCacheConfirmation = false
  @State private var historyInfoText = ""
  @State private var historyClearedTrigger = false
  @State private var cacheClearedTrigger = false
  @State private var snippetCount = 0
  @SceneStorage("selectedTab") private var selectedTab = "history"

  // swiftlint:disable:next line_length
  private let clearHistoryMessage: LocalizedStringKey = "All recordings from the History tab, including transcription text and audio files stored on this device, will be permanently deleted."

  // swiftlint:disable:next line_length
  private let clearCacheMessage: LocalizedStringKey = "Compiled models will be removed from cache. Recompilation will be required on next use, which may take up to a minute."

  // swiftlint:disable:next line_length
  private let sessionFooterMessage: LocalizedStringKey = "Allows the keyboard to start dictation instantly, without switching to the app. The orange dot in the status bar is normal \u{2014} it means the mic session is active."

  private var sessionBinding: Binding<Bool> {
    Binding(
      get: { self.speechService.isSessionActive },
      set: { newValue in
        if newValue {
          try? self.speechService.session.startSession()
        } else {
          self.speechService.session.endSession()
        }
      },
    )
  }

  private var needsSetup: Bool {
    self.permissionService.microphoneState != .granted
      || !self.permissionService.isKeyboardAdded
      || !self.permissionService.hasFullAccess
      || !self.downloadService.hasUsableModel
  }

  private var setupSection: some View {
    Section {
      if self.permissionService.microphoneState != .granted {
        self.microphoneSetupRow
      }
      if !self.permissionService.isKeyboardAdded {
        self.keyboardSetupRow
      }
      if !self.permissionService.hasFullAccess {
        self.fullAccessSetupRow
      }
      if !self.downloadService.hasUsableModel {
        self.modelSetupRow
      }
    } header: {
      Text("\u{26A0}\u{FE0F} Action Required")
    } footer: {
      Text("Sayboard won't work until these settings are configured")
    }
  }

  private var microphoneSetupRow: some View {
    Button {
      self.pipTutorialService.playTutorial(.microphone, language: self.selectedAppLanguage, thenOpenSettings: true)
    } label: {
      Label("Allow Microphone Access", systemImage: "mic.slash")
    }
  }

  private var keyboardSetupRow: some View {
    Button {
      self.pipTutorialService.playTutorial(.addKeyboard, language: self.selectedAppLanguage, thenOpenSettings: true)
    } label: {
      Label("Add Sayboard Keyboard", systemImage: "keyboard")
    }
  }

  private var fullAccessSetupRow: some View {
    Button {
      self.pipTutorialService.playTutorial(.fullAccess, language: self.selectedAppLanguage, thenOpenSettings: true)
    } label: {
      Label("Allow Full Access for Keyboard", systemImage: "lock.open")
    }
  }

  private var modelSetupRow: some View {
    Button {
      self.selectedTab = "models"
    } label: {
      Label("Download Speech Model", systemImage: "arrow.down.circle")
    }
  }

  private var sessionSection: some View {
    Section {
      Toggle("Active Session", isOn: self.sessionBinding)
        .tint(.orange)
      Picker("Auto-Stop", selection: self.$selectedAutoStopPolicy) {
        ForEach(SessionAutoStopPolicy.allCases, id: \.self) { policy in
          Text(LocalizedStringKey(policy.displayNameKey)).tag(policy)
        }
      }
    } header: {
      Text("Dictation")
    } footer: {
      Text(self.sessionFooterMessage)
    }
  }

  private var historySection: some View {
    Section {
      NavigationLink {
        RetentionPolicyListView(selected: self.$selectedRetentionPolicy)
      } label: {
        HStack {
          Text("Keep History")
          Spacer()
          Text(LocalizedStringKey(self.selectedRetentionPolicy.shortDisplayNameKey))
            .foregroundStyle(.secondary)
        }
      }

      self.clearHistoryButton
    } header: {
      Text("History")
    }
  }

  private var textOutputSection: some View {
    Section("Text") {
      NavigationLink {
        WritingStyleListView()
      } label: {
        Text("Writing Style")
      }

      NavigationLink {
        LLMSettingsView()
      } label: {
        HStack {
          Text("AI Text Processing")
          Spacer()
          if self.llmEnabled, self.llmDownloadService.hasUsableModel {
            Text(verbatim: self.llmDownloadService.selectedVariant.displayName)
              .foregroundStyle(.secondary)
          } else {
            Text("Off")
              .foregroundStyle(.secondary)
          }
        }
      }

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
    }
  }

  private var clearHistoryButton: some View {
    Button(role: .destructive) {
      self.showClearHistoryConfirmation = true
    } label: {
      HStack {
        Text("Clear All History")
        Spacer()
        Text(verbatim: self.historyInfoText)
          .foregroundStyle(.secondary)
      }
    }
    .confirmationDialog(
      "Clear All History",
      isPresented: self.$showClearHistoryConfirmation,
      titleVisibility: .visible,
    ) {
      Button("Delete All Recordings", role: .destructive) {
        HistoryStore.shared.deleteAllRecords()
        self.historyClearedTrigger.toggle()
        self.refreshHistoryInfo()
      }
    } message: {
      Text(self.clearHistoryMessage)
    }
  }

  private var aboutSection: some View {
    Section("About") {
      self.appLanguageRow

      Button(role: .destructive) {
        self.showClearCacheConfirmation = true
      } label: {
        HStack {
          Text("Clear Model Cache")
          Spacer()
          Text(verbatim: self.formattedCacheSize)
            .foregroundStyle(.secondary)
        }
      }
      .confirmationDialog(
        "Clear Model Cache",
        isPresented: self.$showClearCacheConfirmation,
        titleVisibility: .visible,
      ) {
        Button("Clear Cache", role: .destructive) {
          ModelStorageManager.clearCompiledModelCache()
          self.cacheClearedTrigger.toggle()
        }
      } message: {
        Text(self.clearCacheMessage)
      }

      HStack {
        Text("Version")
        Spacer()
        Text(verbatim: "1.0.0")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var formattedCacheSize: String {
    let bytes = ModelStorageManager.compiledModelCacheSize()
    guard bytes > 0 else { return "" }
    return bytes.formatted(.byteCount(style: .file).locale(self.locale))
  }

  private var appLanguageRow: some View {
    NavigationLink {
      AppLanguageListView()
    } label: {
      HStack {
        Text("App Language")
        Spacer()
        Text(verbatim: nativeLanguageNames[self.selectedAppLanguage] ?? self.selectedAppLanguage)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func refreshHistoryInfo() {
    let count = HistoryStore.shared.loadRecords().count
    guard count > 0 else { self.historyInfoText = ""
      return
    }
    let bytes = HistoryStore.shared.audioStorageSize()
    guard bytes > 0 else { self.historyInfoText = "\(count)"
      return
    }
    self.historyInfoText = "\(count) \u{00B7} \(bytes.formatted(.byteCount(style: .file).locale(self.locale)))"
  }

}
