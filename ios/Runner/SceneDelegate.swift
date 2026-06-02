import Flutter
import UIKit
import WidgetKit

class SceneDelegate: FlutterSceneDelegate {
    private let appGroup = "group.cn.thebeike.app"
    private let channelName = "cn.thebeike.app/widget"
    private let widgetKind = "cn.thebeike.app.widget"
    private let curriculumDataKey = "curriculum_full_data"

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let windowScene = scene as? UIWindowScene,
           self.window == nil {
            self.window = windowScene.windows.first
        }

        super.scene(scene, willConnectTo: session, options: connectionOptions)

        if self.window == nil,
           let windowScene = scene as? UIWindowScene {
            let flutterVC = FlutterViewController()
            self.window = UIWindow(windowScene: windowScene)
            self.window?.rootViewController = flutterVC
            self.window?.makeKeyAndVisible()
        }

        guard let rootVC = self.window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: rootVC.engine.binaryMessenger
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
