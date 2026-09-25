import SwiftUI

struct KeyboardSettingsView: View {

  @Binding var selectedKind: KeyboardKind

  var body: some View {
    Form {
      Section {
        Picker("Keyboard Type", selection: self.$selectedKind) {
          ForEach(KeyboardKind.allCases, id: \.self) { kind in
            Text(LocalizedStringKey(kind.displayNameKey)).tag(kind)
          }
        }
        Toggle("Haptic Feedback", isOn: self.$keyboardHapticsEnabled)
        if !self.needsInputModeSwitchKey {
          Toggle("Show Keyboard Switch Key", isOn: self.$showGlobeKey)
        }
      } footer: {
        if !self.needsInputModeSwitchKey {
          Text("Display an extra globe key on the keyboard. Your device already provides one, so this is optional.")
        }
      }
    }
    .navigationTitle("Keyboard")
    .navigationBarTitleDisplayMode(.inline)
  }

  @AppStorage(SharedKey.showGlobeKey, store: UserDefaults(suiteName: AppGroup.identifier))
  private var showGlobeKey = true
  @AppStorage(SharedKey.keyboardHapticsEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
  private var keyboardHapticsEnabled = true
  @AppStorage(SharedKey.needsInputModeSwitchKey, store: UserDefaults(suiteName: AppGroup.identifier))
  private var needsInputModeSwitchKey = false
}
