import SwiftUI

struct ContentView: View {

  var body: some View {
    HistoryListView()
      .navigationTitle("History")
      .sheet(isPresented: self.$showOnboarding) { OnboardingView() }
      .onAppear { self.checkOnboarding() }
  }

  // MARK: Private

  @State private var showOnboarding = false

  private func checkOnboarding() {
    let completed = UserDefaults.standard.bool(forKey: SharedKey.hasCompletedOnboarding)
    if !completed {
      self.showOnboarding = true
    }
  }
}
