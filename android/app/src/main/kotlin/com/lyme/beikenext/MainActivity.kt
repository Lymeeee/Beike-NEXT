package com.lyme.beikenext

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_WIDGET = "com.lyme.beikenext/widget"
    private val CHANNEL_BATTERY = "com.lyme.beikenext/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_WIDGET
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateCurriculumData" -> {
                    val data = call.arguments as? String
                    if (data != null) {
                        UpcomingClassWidget.saveFullData(this, data)
                        UpcomingClassWidget.updateAllWidgets(this)
                        UpcomingClassWidget.updateBackgroundRefresh(this)
                    }
                    result.success(null)
                }
                "updateUpcomingClass" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_BATTERY
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatteryOptimizationSettings" -> {
                    val request = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    try {
                        startActivity(request)
                        result.success(true)
                    } catch (e: Exception) {
                        // 部分 ROM 不支持该对话框，退回电池优化的应用列表
                        try {
                            startActivity(
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            )
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
