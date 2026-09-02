
import SwiftUI
import UIKit

struct FeedbackSection: View {

  var body: some View {
    Section {
      Button("Open a GitHub Issue") {
        self.open(SupportLinks.newIssueURL)
      }
      Button("Write an Email") {
        self.openSupportEmail()
      }
    } header: {
      Text("Report a Problem")
    } footer: {
      Text(Self.footerMessage)
    }
    .alert("No Mail App Set Up", isPresented: self.$showsMailFallback) {
      Button("Open a GitHub Issue") {
        self.open(SupportLinks.newIssueURL)
      }
      Button("OK", role: .cancel) { }
    } message: {
      Text(
        """
        This device has no mail app to open, so the address is on your clipboard instead. \
        Paste \(SupportLinks.supportAddress) wherever you read your email.
        """
      )
    }
  }

  private static let footerMessage: LocalizedStringKey = """
    Please report any bug you find. Sayboard has no analytics and no telemetry, \
    so the only bugs we know about are the ones people report.
    """

  @Environment(\.openURL) private var openURL
  @State private var showsMailFallback = false

  private func open(_ url: URL?) {
    guard let url else { return }
    self.openURL(url)
  }

  private func openSupportEmail() {
    guard let url = SupportLinks.supportEmailURL else { return }
    self.openURL(url) { accepted in
      guard !accepted else { return }
      UIPasteboard.general.string = SupportLinks.supportAddress
      self.showsMailFallback = true
    }
  }
}
