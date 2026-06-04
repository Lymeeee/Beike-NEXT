import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let appGroup = "group.com.lyme.beikenext"
    private let channelName = "com.lyme.beikenext/widget"
    private let widgetKind = "com.lyme.beikenext.widget"
    private let curriculumDataKey = "curriculum_full_data"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            if call.method == "updateCurriculumData" {
                if let json = call.arguments as? String {
                    self.saveWidgetData(json, forKey: self.curriculumDataKey)
                    if #available(iOS 14.0, *) {
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
