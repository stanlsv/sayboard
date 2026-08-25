import TipKit

struct ActiveSessionTip: Tip {

  var title: Text {
    Text("Active Session Info")
  }

  var message: Text? {
    Text("active_session_tip_message")
  }

  var image: Image? {
    Image(systemName: "mic.fill")
  }

  var options: [any TipOption] {
    Tips.IgnoresDisplayFrequency(true)
    Tips.MaxDisplayCount(3)
  }
}
