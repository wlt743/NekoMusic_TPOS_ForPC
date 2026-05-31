import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // 持有一个「活动」令牌，禁用 macOS App Nap。
  //
  // 关键修复：当应用失去焦点（点击其他窗口）时，macOS 会让应用进入 App Nap，
  // 节流（throttle）所有 Dart 定时器与 stream 回调，导致桌面歌词的推送/滚动停滞。
  // beginActivity(.userInitiated) 声明应用正在进行用户发起的持续性工作，
  // 阻止系统在后台时降低其活动频率，从而保证失焦后歌词仍能实时滚动。
  private var activityToken: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    activityToken = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .idleSystemSleepDisabled],
      reason: "Keep desktop lyrics scrolling while app is in background"
    )
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationWillTerminate(_ notification: Notification) {
    if let token = activityToken {
      ProcessInfo.processInfo.endActivity(token)
      activityToken = nil
    }
    super.applicationWillTerminate(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
