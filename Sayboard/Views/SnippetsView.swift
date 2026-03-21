// SnippetsView -- List, add, edit, delete text expansion snippets

import SwiftUI

// MARK: - SnippetsView

struct SnippetsView: View {

  // MARK: Internal

  var body: some View {
    Form {
      if self.snippets.isEmpty {
        self.emptyState
      } else {
        self.snippetsSection
      }
    }
    .navigationTitle("Snippets")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          self.activeSheet = .add
        } label: {
          Image(systemName: "plus")
        }
      }
    }
    .sheet(item: self.$activeSheet) { sheet in
      self.sheetContent(for: sheet)
    }
    .onAppear {
      self.snippets = SharedSettings().snippets
    }
  }

  // MARK: Private

  @State private var snippets = [Snippet]()
  @State private var activeSheet: ActiveSheet?

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Snippets", systemImage: "text.badge.plus")
    } description: {
      // swiftlint:disable line_length
      Text(
        "Create snippets to auto-replace phrases when you dictate. Say the trigger phrase, and the replacement text is inserted instead."
      )
      // swiftlint:enable line_length
    } actions: {
      Button("Add Snippet") {
        self.activeSheet = .add
      }
    }
  }

  private var snippetsSection: some View {
    Section {
      ForEach(self.$snippets) { $snippet in
        self.snippetRow(snippet: $snippet)
      }
      .onDelete { offsets in
        self.snippets.remove(atOffsets: offsets)
        self.saveSnippets()
      }
    }
  }

  private func snippetRow(snippet: Binding<Snippet>) -> some View {
    Button {
      self.activeSheet = .edit(snippet.wrappedValue.id)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: snippet.wrappedValue.trigger)
          .font(.body)
        Text(verbatim: snippet.wrappedValue.replacement)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .foregroundStyle(.primary)
  }

  @ViewBuilder
  private func sheetContent(for sheet: ActiveSheet) -> some View {
    switch sheet {
    case .add:
      EditSnippetView(
        title: "Add Snippet",
        trigger: "",
        replacement: "",
      ) { trigger, replacement in
        let newSnippet = Snippet(trigger: trigger, replacement: replacement)
        self.snippets.append(newSnippet)
        self.saveSnippets()
      }

    case .edit(let id):
      if let index = self.snippets.firstIndex(where: { $0.id == id }) {
        EditSnippetView(
          title: "Edit Snippet",
          trigger: self.snippets[index].trigger,
          replacement: self.snippets[index].replacement,
        ) { trigger, replacement in
          self.snippets[index].trigger = trigger
          self.snippets[index].replacement = replacement
          self.saveSnippets()
        }
      }
    }
  }

  private func saveSnippets() {
    SharedSettings().snippets = self.snippets
  }
}

// MARK: SnippetsView.ActiveSheet

extension SnippetsView {
  fileprivate enum ActiveSheet: Identifiable {
    case add
    case edit(UUID)

    var id: String {
      switch self {
      case .add:
        "add"
      case .edit(let uuid):
        "edit-\(uuid.uuidString)"
      }
    }
  }
}

// MARK: - EditSnippetView

private struct EditSnippetView: View {

  // MARK: Internal

  let title: LocalizedStringKey
  @State var trigger: String
  @State var replacement: String

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
      Section("Trigger Phrase") {
        TextField("What you say", text: self.$trigger)
          .autocorrectionDisabled()
      }
      Section("Replacement Text") {
        TextField("What gets inserted", text: self.$replacement)
          .autocorrectionDisabled()
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
          self.onSave(
            self.trigger.trimmingCharacters(in: .whitespacesAndNewlines),
            self.replacement.trimmingCharacters(in: .whitespacesAndNewlines),
          )
          self.dismiss()
        }
        .disabled(self.isSaveDisabled)
      }
    }
  }

  private var isSaveDisabled: Bool {
    self.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || self.replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
