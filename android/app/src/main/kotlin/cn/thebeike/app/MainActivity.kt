package cn.thebeike.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cn.thebeike.app/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "updateUpcomingClass") {
                val data = call.arguments as? String
                if (data != null) {
                    UpcomingClassWidget.saveData(this, data)
                    UpcomingClassWidget.updateAllWidgets(this)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
