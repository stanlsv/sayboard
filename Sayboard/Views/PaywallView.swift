
import SwiftUI
#if APPSTORE

import StoreKit

#endif

extension View {
  func purchaseScreen(isPresented: Binding<Bool>) -> some View {
    #if APPSTORE
    self.sheet(isPresented: isPresented) {
      PaywallView()
    }
    #else
    self
    #endif
  }
}

#if APPSTORE

enum PurchaseNotice {
  case pending
  case purchaseFailed
  case nothingToRestore
  case restoreFailed

  init?(_ outcome: PurchaseService.RestoreOutcome) {
    switch outcome {
    case .restored, .cancelled: return nil
    case .nothingToRestore: self = .nothingToRestore
    case .failed: self = .restoreFailed
    }
  }

  var text: LocalizedStringKey {
    switch self {
    case .pending: "Waiting for purchase approval"
    case .purchaseFailed: "The purchase didn’t go through. Please try again."
    case .nothingToRestore: "No purchases to restore"
    case .restoreFailed: "Purchases couldn’t be restored. Please try again."
    }
  }
}

struct PaywallView: View {

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 32) {
          self.header
          self.purchaseControls
          self.sourceCodeNote
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { self.dismiss() }
        }
      }
    }
    .task { await self.loadProduct() }
    .onChange(of: self.entitlementStatus, initial: true) { _, status in
      if status == .unlocked { self.dismiss() }
    }
  }

  private static let pitch: LocalizedStringKey = """
    A one-time purchase unlocks unlimited dictation and AI text processing for good \
    and supports Sayboard’s development.
    """

  private static let sourceCodeMessage: LocalizedStringKey = """
    Sayboard is open source. If you would rather not pay, you can build it yourself for free.
    """

  private static let sourceCodeURL = URL(string: "https://github.com/stanlsv/sayboard")
  private static let productRetryDelay = Duration.seconds(5)

  @Environment(\.dismiss) private var dismiss
  @Environment(\.purchase) private var purchase
  @ObservedObject private var purchaseService = PurchaseService.shared
  @AppStorage(SharedKey.entitlementStatus, store: UserDefaults(suiteName: AppGroup.identifier))
  private var entitlementStatus = EntitlementStatus.unknown
  @State private var isBusy = false
  @State private var notice: PurchaseNotice?

  private var header: some View {
    VStack(spacing: 16) {
      Image(systemName: "heart.fill")
        .font(.system(size: 56))
        .foregroundStyle(.pink)
        .accessibilityHidden(true)
      Text("Support Sayboard")
        .font(.largeTitle.bold())
      Text(Self.pitch)
        .foregroundStyle(.secondary)
    }
    .multilineTextAlignment(.center)
  }

  private var purchaseControls: some View {
    VStack(spacing: 16) {
      Button {
        Task { await self.buy() }
      } label: {
        Group {
          if let product = self.purchaseService.product, !self.isBusy {
            Text("Unlock for \(product.displayPrice)")
          } else {
            ProgressView()
              .accessibilityLabel(Text("Get Full Version"))
          }
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(self.purchaseService.product == nil || self.isBusy)

      Button("Restore Purchases") {
        Task { await self.restore() }
      }
      .disabled(self.isBusy)

      if let notice = self.notice {
        Text(notice.text)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  private var sourceCodeNote: some View {
    VStack(spacing: 8) {
      Text(Self.sourceCodeMessage)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let url = Self.sourceCodeURL {
        Link("Source Code on GitHub", destination: url)
          .font(.footnote)
      }
    }
  }

  private func loadProduct() async {
    while !Task.isCancelled {
      await self.purchaseService.loadProductIfNeeded()
      guard self.purchaseService.product == nil else { return }
      try? await Task.sleep(for: Self.productRetryDelay)
    }
  }

  private func buy() async {
    guard let product = self.purchaseService.product else { return }
    self.isBusy = true
    defer { self.isBusy = false }
    self.notice = nil
    do {
      let result = try await self.purchase(product)
      switch await self.purchaseService.complete(result) {
      case .purchased, .cancelled: break
      case .pending: self.notice = .pending
      case .failed: self.notice = .purchaseFailed
      }
    } catch StoreKitError.userCancelled {
      return
    } catch {
      self.notice = .purchaseFailed
    }
  }

  private func restore() async {
    self.isBusy = true
    defer { self.isBusy = false }
    self.notice = nil
    self.notice = PurchaseNotice(await self.purchaseService.restore())
  }
}

#endif
