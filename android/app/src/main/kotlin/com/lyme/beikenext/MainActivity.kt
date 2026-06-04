package com.lyme.beikenext

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lyme.beikenext/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateCurriculumData" -> {
                    val data = call.arguments as? String
                    if (data != null) {
                        UpcomingClassWidget.saveFullData(this, data)
                        UpcomingClassWidget.updateAllWidgets(this)
                    }
                    result.success(null)
                }
                "updateUpcomingClass" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
