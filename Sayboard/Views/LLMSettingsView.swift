// LLMSettingsView -- Settings for AI text processing: enable/disable, default action, custom prompts

import SwiftUI
import UIKit

// MARK: - LLMSettingsView

struct LLMSettingsView: View {

  // MARK: Internal

  var body: some View {
    Form {
      self.enableSection
      if self.showNoModelBanner || (self.llmEnabled && !self.llmDownloadService.hasUsableModel) {
        self.noModelBanner
      } else if self.llmEnabled {
        self.promptsLink
        self.defaultActionSection
        self.longPressActionSection
      }
    }
    .navigationTitle("AI Text Processing")
    .navigationBarTitleDisplayMode(.inline)
    .animation(.easeInOut(duration: 0.3), value: self.llmEnabled)
    .animation(.easeInOut(duration: 0.3), value: self.showNoModelBanner)
    .onAppear {
      let shared = SharedSettings()
      self.defaultActionSelection = shared.defaultLLMActionSelection
      self.customPrompts = shared.llmCustomPrompts
      self.longPressAction = shared.longPressLLMAction
      self.disabledActions = shared.disabledLLMActions
      if self.llmEnabled, !self.llmDownloadService.hasUsableModel {
        self.llmEnabled = false
      }
    }
    .onDisappear {
      self.showNoModelBanner = false
    }
  }

  // MARK: Private

  private static let toggleRevertDelay: UInt64 = 200_000_000

  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @AppStorage(SharedKey.llmEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
  private var llmEnabled = false
  @State private var defaultActionSelection = LLMActionSelection.none
  @State private var customPrompts = [LLMCustomPrompt]()
  @State private var longPressAction = LLMActionSelection.none
  @State private var disabledActions = Set<LLMAction>()
  @State private var showNoModelBanner = false

  private var validatedToggleBinding: Binding<Bool> {
    Binding(
      get: { self.llmEnabled },
      set: { newValue in
        if newValue, !self.llmDownloadService.hasUsableModel {
          self.llmEnabled = true
          Task {
            try? await Task.sleep(nanoseconds: Self.toggleRevertDelay)
            self.llmEnabled = false
            self.showNoModelBanner = true
          }
        } else {
          self.llmEnabled = newValue
          if !newValue {
            self.showNoModelBanner = false
          }
        }
      },
    )
  }

  private var enableSection: some View {
    Section {
      Toggle("AI Text Processing", isOn: self.validatedToggleBinding)
    } footer: {
      Text("Adds an AI button to the keyboard for rewriting, reformatting, and other text actions.")
    }
  }

  private var noModelBanner: some View {
    Section {
      HStack(spacing: 10) {
        Image(systemName: "arrow.down.circle")
          .font(.title3)
          .foregroundStyle(.orange)
        Text("Download a text processing model to enable AI features")
          .font(.subheadline.weight(.medium))
        Spacer(minLength: 4)
        Button {
          if let url = DeepLink.llmModelsURL {
            UIApplication.shared.open(url)
          }
        } label: {
          Text("Open Models")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white)
            .foregroundStyle(.black)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
      .listRowBackground(Color.orange.opacity(0.1))
    }
  }

  private var promptsLink: some View {
    Section {
      NavigationLink {
        LLMPromptsView()
      } label: {
        LabeledContent("Prompts") {
          Text(self.promptsSummary)
            .foregroundStyle(.secondary)
        }
      }
    } footer: {
      Text("Actions that appear when you tap the AI button on the keyboard.")
    }
  }

  private var promptsSummary: String {
    let enabledStandardCount = LLMAction.enabledActions(excluding: self.disabledActions).count
    let customCount = self.customPrompts.count
    let totalCount = enabledStandardCount + customCount
    return "\(totalCount)"
  }

  private var defaultActionSection: some View {
    Section {
      Picker("Auto Action", selection: self.$defaultActionSelection) {
        self.actionPickerContent()
      }
      .onChange(of: self.defaultActionSelection) { _, newValue in
        SharedSettings().defaultLLMActionSelection = newValue
      }
    } footer: {
      Text("This action will run automatically after every dictated text.")
    }
  }

  private var longPressActionSection: some View {
    Section {
      Picker("Long Press Action", selection: self.$longPressAction) {
        self.actionPickerContent()
      }
      .onChange(of: self.longPressAction) { _, newValue in
        SharedSettings().longPressLLMAction = newValue
      }
    } footer: {
      Text("Long-pressing the AI button on keyboard runs this action directly, skipping the action list.")
    }
  }

  @ViewBuilder
  private func actionPickerContent() -> some View {
    Section {
      Text("Off").tag(LLMActionSelection.none)
    }
    Section {
      ForEach(LLMAction.enabledActions(excluding: self.disabledActions), id: \.self) { action in
        Text(LocalizedStringKey(action.displayNameKey))
          .tag(LLMActionSelection.preset(action))
      }
    }
    if !self.customPrompts.isEmpty {
      Section {
        ForEach(self.customPrompts) { prompt in
          Text(verbatim: prompt.name)
            .tag(LLMActionSelection.customPrompt(prompt.id))
        }
      }
    }
  }

}

// MARK: - LLMPromptsView

private struct LLMPromptsView: View {

  // MARK: Internal

  var body: some View {
    Form {
      self.standardPromptsSection
      self.customPromptsSection
    }
    .navigationTitle("Prompts")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: self.$activeSheet) { sheet in
      self.sheetContent(for: sheet)
    }
    .onAppear {
      let shared = SharedSettings()
      self.disabledActions = shared.disabledLLMActions
      self.customPrompts = shared.llmCustomPrompts
    }
  }

  // MARK: Private

  private enum ActiveSheet: Identifiable {
    case addPrompt
    case editPrompt(UUID)

    var id: String {
      switch self {
      case .addPrompt:
        "addPrompt"
      case .editPrompt(let uuid):
        "editPrompt-\(uuid.uuidString)"
      }
    }
  }

  @State private var disabledActions = Set<LLMAction>()
  @State private var customPrompts = [LLMCustomPrompt]()
  @State private var activeSheet: ActiveSheet?

  private var standardPromptsSection: some View {
    Section {
      ForEach(LLMAction.allCases, id: \.rawValue) { action in
        self.standardPromptToggle(for: action)
      }
    } header: {
      Text("Standard Prompts")
    }
    .listSectionSpacing(.compact)
  }

  private var customPromptsSection: some View {
    Section {
      ForEach(self.$customPrompts) { $prompt in
        self.promptRow(prompt: $prompt)
      }
      .onDelete { offsets in
        self.customPrompts.remove(atOffsets: offsets)
        self.saveCustomPrompts()
      }
      Button {
        self.activeSheet = .addPrompt
      } label: {
        Label("Add Custom Prompt", systemImage: "plus")
      }
    } header: {
      Text("Custom Prompts")
    }
  }

  @ViewBuilder
  private func sheetContent(for sheet: ActiveSheet) -> some View {
    switch sheet {
    case .addPrompt:
      EditPromptView(
        title: "New Prompt",
        name: "",
        prompt: "",
      ) { name, prompt in
        let newPrompt = LLMCustomPrompt(name: name, prompt: prompt)
        self.customPrompts.append(newPrompt)
        self.saveCustomPrompts()
      }

    case .editPrompt(let id):
      if let index = self.customPrompts.firstIndex(where: { $0.id == id }) {
        EditPromptView(
          title: "Edit Prompt",
          name: self.customPrompts[index].name,
          prompt: self.customPrompts[index].prompt,
        ) { name, newPrompt in
          self.customPrompts[index].name = name
          self.customPrompts[index].prompt = newPrompt
          self.saveCustomPrompts()
        }
      }
    }
  }

  private func standardPromptToggle(for action: LLMAction) -> some View {
    let isEnabled = !self.disabledActions.contains(action)
    return Toggle(isOn: Binding(
      get: { isEnabled },
      set: { newValue in
        if newValue {
          self.disabledActions.remove(action)
        } else {
          let enabledStandard = LLMAction.enabledActions(excluding: self.disabledActions)
          let isLastStandard = enabledStandard.count == 1 && enabledStandard.first == action
          if isLastStandard, self.customPrompts.isEmpty {
            return
          }
          self.disabledActions.insert(action)
          self.reconcileAfterDisabling(action)
        }
        SharedSettings().disabledLLMActions = self.disabledActions
      },
    )) {
      Text(LocalizedStringKey(action.displayNameKey))
    }
  }

  private func reconcileAfterDisabling(_ action: LLMAction) {
    let shared = SharedSettings()
    if case .preset(let defaultPreset) = shared.defaultLLMActionSelection, defaultPreset == action {
      shared.defaultLLMActionSelection = .none
    }
    if case .preset(let longPressPreset) = shared.longPressLLMAction, longPressPreset == action {
      shared.longPressLLMAction = .none
    }
  }

  private func promptRow(prompt: Binding<LLMCustomPrompt>) -> some View {
    Button {
      self.activeSheet = .editPrompt(prompt.wrappedValue.id)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: prompt.wrappedValue.name)
          .font(.body)
        Text(verbatim: prompt.wrappedValue.prompt)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .foregroundStyle(.primary)
  }

  private func saveCustomPrompts() {
    let shared = SharedSettings()
    shared.llmCustomPrompts = self.customPrompts
    if
      case .customPrompt(let id) = shared.defaultLLMActionSelection,
      !self.customPrompts.contains(where: { $0.id == id })
    {
      shared.defaultLLMActionSelection = .none
    }
    if
      case .customPrompt(let id) = shared.longPressLLMAction,
      !self.customPrompts.contains(where: { $0.id == id })
    {
      shared.longPressLLMAction = .none
    }
    let enabledStandard = LLMAction.enabledActions(excluding: self.disabledActions)
    if enabledStandard.isEmpty, self.customPrompts.isEmpty, let first = LLMAction.allCases.first {
      self.disabledActions.remove(first)
      shared.disabledLLMActions = self.disabledActions
    }
  }
}

// MARK: - EditPromptView

private struct EditPromptView: View {

  // MARK: Internal

  let title: LocalizedStringKey
  @State var name: String
  @State var prompt: String

  let onSave: (String, String) -> Void

  var body: some View {
    NavigationStack {
      self.form
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  private var form: some View {
    Form {
      Section("Name") {
        TextField("Prompt name", text: self.$name)
      }
      Section("Instruction") {
        TextEditor(text: self.$prompt)
          .frame(minHeight: 100)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          self.dismiss()
        }
      }
      ToolbarItem(placement: .principal) {
        Text(self.title)
          .fontWeight(.semibold)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          self.onSave(self.name.trimmingCharacters(in: .whitespacesAndNewlines), self.prompt)
          self.dismiss()
        }
        .disabled(self.isSaveDisabled)
      }
    }
  }

  private var isSaveDisabled: Bool {
    self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || self.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
