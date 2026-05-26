package cn.thebeike.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews

class UpcomingClassWidget : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "cn.thebeike.app.widget"
        private const val KEY_DATA = "upcoming_class_data"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = buildRemoteViews(context)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, UpcomingClassWidget::class.java)
            )
            for (widgetId in widgetIds) {
                updateWidget(context, appWidgetManager, widgetId)
            }
        }

        fun saveData(context: Context, json: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_DATA, json).apply()
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_class)

            applyMonetColors(context, views)
            fillContent(context, views)

            return views
        }

        private fun applyMonetColors(context: Context, views: RemoteViews) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

            val surface = getMonetColor(context, android.R.color.system_accent1_10)
                ?: getMonetColor(context, android.R.color.system_accent2_10)
                ?: getMonetColor(context, android.R.color.system_accent3_10)
                ?: getMonetColor(context, android.R.color.system_neutral1_10)

            if (surface != null) {
                views.setInt(R.id.widget_container, "setBackgroundColor", surface)
            }
        }

        private fun fillContent(context: Context, views: RemoteViews) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_DATA, null)

            if (json != null) {
                try {
                    val data = org.json.JSONObject(json)
                    if (data.optBoolean("hasClass", false)) {
                        views.setTextViewText(R.id.label_text, "")
                        views.setTextViewText(R.id.class_name_text, data.optString("className", ""))
                        views.setTextViewText(R.id.time_text, data.optString("timeRange", ""))
                        views.setTextViewText(R.id.location_text, data.optString("location", ""))
                        views.setTextViewText(R.id.teacher_text, data.optString("teacher", ""))
                        attachClickIntent(context, views)
                        return
                    }
                } catch (_: Exception) { }
            }

            views.setTextViewText(R.id.label_text, "")
            views.setTextViewText(R.id.class_name_text, "今天没有课了")
            views.setTextViewText(R.id.time_text, "")
            views.setTextViewText(R.id.location_text, "")
            views.setTextViewText(R.id.teacher_text, "")
            attachClickIntent(context, views)
        }

        private fun attachClickIntent(context: Context, views: RemoteViews) {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pi)
            }
        }

        private fun getMonetColor(context: Context, resId: Int): Int? {
            return try { context.getColor(resId) } catch (_: Exception) { null }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) { }

    override fun onDisabled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
    }
}
