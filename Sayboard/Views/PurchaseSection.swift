
#if APPSTORE
import SwiftUI

struct PurchaseSection: View {

  var body: some View {
    switch self.entitlementStatus {
    case .unknown:
      Section {
        self.restoreButton
          .onAppear { PurchaseService.shared.refreshIfUnverified() }
      }

    case .unlocked:
      EmptyView()

    case .free:
      self.freeSection
    }
  }

  private static let footerMessage: LocalizedStringKey = """
    Sayboard includes \(DictationAllowance.freeWords) free words of dictation so you can try it at your own pace. \
    If you enjoy it, a one-time purchase keeps dictation going once they run out and supports its development, \
    and we are sincerely grateful for it. \
    If you would rather not pay, Sayboard is open source, and you can build it yourself free of charge.
    """

  @AppStorage(SharedKey.entitlementStatus, store: UserDefaults(suiteName: AppGroup.identifier))
  private var entitlementStatus = EntitlementStatus.unknown
  @AppStorage(SharedKey.freeWordsUsed, store: UserDefaults(suiteName: AppGroup.identifier))
  private var freeWordsUsed = 0
  @State private var isRestoring = false
  @State private var restoreNotice: PurchaseNotice?

  private var remainingWords: Int {
    DictationAllowance(status: self.entitlementStatus, wordsUsed: self.freeWordsUsed).remainingWords
  }

  private var freeSection: some View {
    Section {
      LabeledContent {
        Text("\(self.remainingWords) words left")
      } label: {
        Text("Free Dictation")
      }
      Button("Get Full Version") {
        NotificationCenter.default.post(name: .purchaseScreenRequested, object: nil)
      }
      self.restoreButton
    } footer: {
      Text(Self.footerMessage)
    }
  }

  private var restoreButton: some View {
    Button("Restore Purchases") {
      Task { await self.restore() }
    }
    .disabled(self.isRestoring)
    .alert("Restore Purchases", isPresented: self.isRestoreNoticePresented) {
      Button("OK") { }
    } message: {
      if let notice = self.restoreNotice {
        Text(notice.text)
      }
    }
  }

  private var isRestoreNoticePresented: Binding<Bool> {
    Binding(
      get: { self.restoreNotice != nil },
      set: { if !$0 { self.restoreNotice = nil } },
    )
  }

  private func restore() async {
    self.isRestoring = true
    defer { self.isRestoring = false }
    self.restoreNotice = PurchaseNotice(await PurchaseService.shared.restore())
  }
}

struct FullVersionRow: View {

  var body: some View {
    if self.entitlementStatus == .unlocked {
      HStack {
        Text("Full Version")
        Spacer()
        SetupCompletedMark()
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Full Version"))
      .accessibilityValue(Text("Purchased"))
    }
  }

  @AppStorage(SharedKey.entitlementStatus, store: UserDefaults(suiteName: AppGroup.identifier))
  private var entitlementStatus = EntitlementStatus.unknown
}
#endif
