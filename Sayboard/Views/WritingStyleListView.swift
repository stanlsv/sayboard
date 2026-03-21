import SwiftUI

// MARK: - WritingStyleListView

struct WritingStyleListView: View {

  // MARK: Internal

  var body: some View {
    List {
      self.searchSection
      self.searchResultsSection
      self.defaultStyleSection
      if self.entries.isEmpty, self.searchText.isEmpty {
        self.emptyAppsSection
      }
      if !self.entries.isEmpty {
        self.addedAppsSection
      }
    }
    .navigationTitle("Writing Style")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: self.$showDefaultStylePicker) {
      DefaultStylePickerView(selectedStyle: self.defaultStyleBinding)
    }
    .sheet(
      item: self.$editingEntry,
      onDismiss: { self.entries = self.store.loadEntries() },
      content: { entry in
        StyleSelectionView(
          appName: entry.name,
          bundleId: entry.bundleId,
          iconURL: entry.iconURL,
          currentStyle: self.store.style(for: entry.bundleId),
        ) {
          self.entries = self.store.loadEntries()
        }
      },
    )
    .onAppear {
      self.entries = self.store.loadEntries()
      self.defaultStyle = self.settings.defaultWritingStyle
    }
  }

  // MARK: Private

  private static let iconSize: CGFloat = 32
  private static let iconCornerRadius: CGFloat = 7.2
  private static let searchRowMinHeight: CGFloat = 22

  @State private var searchText = ""
  @State private var entries = [AppStyleEntry]()
  @State private var searchService = AppSearchService()
  @State private var showDefaultStylePicker = false
  @State private var editingEntry: AppStyleEntry?
  @State private var defaultStyle = WritingStyle.formal
  @FocusState private var isSearchFocused: Bool

  private let store = AppStyleStore()
  private let settings = SharedSettings()

  private var filteredResults: [AppSearchResult] {
    let addedBundleIds = Set(self.entries.map(\.bundleId))
    return self.searchService.results.filter { !addedBundleIds.contains($0.bundleId) }
  }

  private var defaultStyleBinding: Binding<WritingStyle> {
    Binding(
      get: { self.defaultStyle },
      set: { newValue in
        self.defaultStyle = newValue
        self.settings.defaultWritingStyle = newValue
      },
    )
  }

  private var defaultStyleSection: some View {
    Section {
      Button {
        self.showDefaultStylePicker = true
      } label: {
        HStack(spacing: 12) {
          self.defaultStyleIcon
          Text("All Apps")
            .lineLimit(1)
          Spacer()
          Text(LocalizedStringKey(self.defaultStyle.displayNameKey))
            .foregroundStyle(.secondary)
        }
      }
      .foregroundStyle(.primary)
    } header: {
      Text("Default Style")
    }
  }

  private var defaultStyleIcon: some View {
    RoundedRectangle(cornerRadius: Self.iconCornerRadius, style: .continuous)
      .fill(Color.accentColor.gradient)
      .frame(width: Self.iconSize, height: Self.iconSize)
      .overlay {
        Image("icon-grid")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 20, height: 20)
          .foregroundStyle(.white)
      }
  }

  private var searchSection: some View {
    Section {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search apps", text: Binding(
          get: { self.searchText },
          set: { newValue in
            self.searchText = newValue
            self.searchService.search(query: newValue)
          },
        ))
        .focused(self.$isSearchFocused)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        Button {
          self.searchText = ""
          self.searchService.search(query: "")
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .opacity(self.searchText.isEmpty ? 0 : 1)
        .disabled(self.searchText.isEmpty)
      }
      .frame(minHeight: Self.searchRowMinHeight)
    } footer: {
      Text("Sayboard can't see your installed apps. Search is performed in the App Store, so make sure you select the right app.")
    }
  }

  @ViewBuilder
  private var searchResultsSection: some View {
    if !self.searchText.isEmpty {
      Section {
        if self.searchService.phase == .searching {
          HStack {
            Spacer()
            ProgressView()
              .id(self.searchService.searchId)
            Spacer()
          }
        }

        if self.searchService.phase == .done, self.filteredResults.isEmpty {
          Text("No results")
            .foregroundStyle(.secondary)
        }

        ForEach(self.filteredResults) { result in
          self.searchResultRow(result)
        }
      } header: {
        Text("Search Results")
      }
    }
  }

  private var emptyAppsSection: some View {
    Section {
      ContentUnavailableView {
        Label {
          Text("No apps added")
        } icon: {
          Image("icon-grid")
            .resizable()
            .frame(width: 48, height: 48)
        }
      } description: {
        Text("Search for apps to set their writing style.")
      }
    }
    .listRowBackground(Color.clear)
  }

  private var addedAppsSection: some View {
    Section {
      ForEach(self.entries) { entry in
        Button {
          self.editingEntry = entry
        } label: {
          self.appEntryRow(entry)
        }
        .foregroundStyle(.primary)
      }
      .onDelete { offsets in
        let idsToRemove = offsets.map { self.entries[$0].bundleId }
        for bundleId in idsToRemove {
          self.store.removeEntry(bundleId: bundleId)
        }
        self.entries.remove(atOffsets: offsets)
      }
    } header: {
      Text("Individual App Style")
    }
  }

  private func searchResultRow(_ result: AppSearchResult) -> some View {
    HStack(spacing: 12) {
      self.appIcon(url: result.iconURL)
      Text(verbatim: result.trackName)
        .lineLimit(1)
      Spacer()
      Button {
        self.addApp(from: result)
      } label: {
        Image(systemName: "plus.circle")
          .font(.title2)
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
    }
  }

  private func appEntryRow(_ entry: AppStyleEntry) -> some View {
    HStack(spacing: 12) {
      self.appIcon(url: entry.iconURL)
      Text(verbatim: entry.name)
        .lineLimit(1)
      Spacer()
      Text(LocalizedStringKey(entry.style.displayNameKey))
        .foregroundStyle(.secondary)
    }
  }

  private func appIcon(url: URL?) -> some View {
    AsyncImage(url: url) { image in
      image
        .resizable()
        .aspectRatio(contentMode: .fill)
    } placeholder: {
      RoundedRectangle(cornerRadius: Self.iconCornerRadius, style: .continuous)
        .fill(.quaternary)
    }
    .frame(width: Self.iconSize, height: Self.iconSize)
    .clipShape(RoundedRectangle(cornerRadius: Self.iconCornerRadius, style: .continuous))
  }

  private func addApp(from result: AppSearchResult) {
    self.searchText = ""
    self.searchService.search(query: "")
    self.isSearchFocused = false
    self.editingEntry = AppStyleEntry(
      bundleId: result.bundleId,
      name: result.trackName,
      iconURL: result.iconURL,
      style: .formal,
    )
  }

}
