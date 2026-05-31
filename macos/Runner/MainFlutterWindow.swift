import Cocoa
import FlutterMacOS
import desktop_multi_window

/// 递归把视图及其所有子视图的 CALayer 设为透明，
/// 用于让 desktop_multi_window 子窗口（桌面歌词）的 Flutter 背板透明，
/// 否则半透明黑底会叠在不透明背板上，导致透明度/圆角看起来不生效。
private func makeViewTransparent(_ view: NSView) {
  view.wantsLayer = true
  view.layer?.isOpaque = false
  view.layer?.backgroundColor = NSColor.clear.cgColor
  for sub in view.subviews {
    makeViewTransparent(sub)
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 为 desktop_multi_window 创建的子窗口（桌面歌词窗口）注册插件，
    // 否则子窗口的 method channel 无法连接，歌词无法显示/接收推送。
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)

      // 在子窗口引擎上注册一个原生通道，供歌词窗口的 Flutter 侧在运行时
      // 切换「点击穿透」以及发起「拖动窗口」。
      let channel = FlutterMethodChannel(
        name: "neko_lyrics_native",
        binaryMessenger: controller.engine.binaryMessenger
      )
      // 拖动窗口用的鼠标事件监听器（避免依赖 NSApp.currentEvent 导致拖动不稳定）
      var dragMonitor: Any?
      channel.setMethodCallHandler { call, result in
        guard let window = controller.view.window else {
          result(nil)
          return
        }
        switch call.method {
        case "setClickThrough":
          // true = 穿透（不挡点击）；false = 可交互、可拖动
          let enabled = (call.arguments as? Bool) ?? true
          window.ignoresMouseEvents = enabled
          result(nil)
        case "startDrag":
          // 用本地事件监听器实现可靠拖动：
          // 记录起始鼠标(屏幕坐标)与窗口原点，跟随 leftMouseDragged 移动窗口，
          // leftMouseUp 时移除监听。相比 performDrag(with: currentEvent) 不会因
          // 异步 method channel 丢失原始事件而出现「拖动不是 100% 成功」。
          if let existing = dragMonitor {
            NSEvent.removeMonitor(existing)
            dragMonitor = nil
          }
          let startMouse = NSEvent.mouseLocation
          let startOrigin = window.frame.origin
          dragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
          ) { event in
            if event.type == .leftMouseUp {
              if let m = dragMonitor {
                NSEvent.removeMonitor(m)
                dragMonitor = nil
              }
              return event
            }
            let now = NSEvent.mouseLocation
            window.setFrameOrigin(
              NSPoint(
                x: startOrigin.x + (now.x - startMouse.x),
                y: startOrigin.y + (now.y - startMouse.y)
              )
            )
            return event
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // 配置桌面歌词子窗口：独立的、可拖动的浮动窗口（默认可交互，不穿透）。
      // - 始终置顶：浮于其他应用之上，可在所有 Space / 全屏应用前显示。
      // - 可交互：ignoresMouseEvents = false，窗口正常接收鼠标事件，可点击按钮。
      // - 可拖动：isMovableByWindowBackground = true，按住窗口背景即可整体拖动；
      //   另配合 startDrag 通道实现的事件监听拖动，双保险。
      // 仍保留透明背景以呈现圆角胶囊外观。点击穿透改为可选项，默认关闭。
      DispatchQueue.main.async {
        guard let window = controller.view.window else { return }
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.styleMask = [.borderless]
        window.collectionBehavior = [
          .canJoinAllSpaces,
          .stationary,
          .ignoresCycle,
          .fullScreenAuxiliary,
        ]

        // 关键：让 Flutter 内容视图（及其 CALayer）透明。
        // 否则即使 NSWindow 设为非透明，Flutter 的 backing layer 仍是不透明的，
        // 半透明黑底会叠加在不透明背景上 → 透明度看起来永远是实心、圆角也被同色矩形遮住，
        // 导致「透明度 / 圆角无法生效」。
        // Flutter 在视图初始化完成后可能重置 backing layer，所以立即应用一次，
        // 再延迟若干次重复应用，确保 FlutterView 的图层最终被设为透明。
        if let contentView = window.contentView {
          makeViewTransparent(contentView)
        }
        for delay in [0.05, 0.2, 0.5, 1.0] {
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let contentView = window.contentView {
              makeViewTransparent(contentView)
            }
          }
        }
      }
    }

    super.awakeFromNib()
  }
}
