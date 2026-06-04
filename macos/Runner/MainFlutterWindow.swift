import Cocoa
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  private let appGroup = "group.com.lyme.beikenext"
  private let channelName = "com.lyme.beikenext/widget"
  private let widgetKind = "com.lyme.beikenext.widget"
  private let curriculumDataKey = "curriculum_full_data"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else {
            result(FlutterMethodNotImplemented)
            return
        }
        if call.method == "updateCurriculumData" {
            if let json = call.arguments as? String {
                self.saveWidgetData(json, forKey: self.curriculumDataKey)
                if #available(macOS 11.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
                }
            }
            result(nil)
        } else if call.method == "updateUpcomingClass" {
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    super.awakeFromNib()
  }

  private func saveWidgetData(_ json: String, forKey key: String) {
    if let defaults = UserDefaults(suiteName: appGroup) {
      defaults.set(json, forKey: key)
      defaults.synchronize()
    }
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) {
      let fileURL = containerURL.appendingPathComponent("\(key).json")
      try? json.write(to: fileURL, atomically: true, encoding: .utf8)
    }
  }
}
