import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var thermal: ThermalStreamHandler?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    thermal = ThermalStreamHandler.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// The device's thermal state for the quality tiers (moonshot M11 ruling 12):
/// `ProcessInfo.thermalState` as the Dart `ThermalLevel` name (nominal,
/// fair → light, serious → moderate, critical), answered on
/// `yofardev/thermal_state` (`current`) and streamed on `yofardev/thermal`.
/// Local OS state only, nothing leaves the device.
final class ThermalStreamHandler: NSObject, FlutterStreamHandler {
  private var observer: NSObjectProtocol?

  static func register(with messenger: FlutterBinaryMessenger) -> ThermalStreamHandler {
    let handler = ThermalStreamHandler()
    FlutterMethodChannel(name: "yofardev/thermal_state", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "current" {
          result(ThermalStreamHandler.levelName())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "yofardev/thermal", binaryMessenger: messenger)
      .setStreamHandler(handler)
    return handler
  }

  static func levelName() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return "nominal"
    case .fair: return "light"
    case .serious: return "moderate"
    case .critical: return "critical"
    @unknown default: return "nominal"
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    events(ThermalStreamHandler.levelName())
    observer = NotificationCenter.default.addObserver(
      forName: ProcessInfo.thermalStateDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      events(ThermalStreamHandler.levelName())
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    return nil
  }
}
