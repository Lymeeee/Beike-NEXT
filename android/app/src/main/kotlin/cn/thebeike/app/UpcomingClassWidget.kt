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

            // Apply Monet dynamic accent color on API 31+
            val accentColor = getMonetAccentColor(context)
            views.setInt(R.id.accent_bar, "setBackgroundColor", accentColor)

            // Apply Monet text colors and tint icons on API 31+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val textPrimary = getMonetColor(context, android.R.color.system_neutral1_900)
                val textSecondary = getMonetColor(context, android.R.color.system_neutral1_400)
                val textTertiary = getMonetColor(context, android.R.color.system_neutral1_100)

                if (textPrimary != null) {
                    views.setTextColor(R.id.class_name_text, textPrimary)
                }
                if (textSecondary != null) {
                    views.setTextColor(R.id.label_text, textSecondary)
                    views.setTextColor(R.id.time_text, textSecondary)
                }
                if (textTertiary != null) {
                    views.setTextColor(R.id.location_text, textTertiary)
                    views.setTextColor(R.id.teacher_text, textTertiary)
                    views.setInt(R.id.location_icon, "setColorFilter", textTertiary)
                    views.setInt(R.id.person_icon, "setColorFilter", textTertiary)
                }
            }

            // Read saved upcoming class data
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_DATA, null)

            if (json.isNullOrEmpty()) {
                views.setTextViewText(R.id.label_text, "")
                views.setTextViewText(R.id.class_name_text, context.getString(R.string.widget_label_no_class))
                views.setTextViewText(R.id.time_text, "")
                views.setTextViewText(R.id.location_text, "")
                views.setTextViewText(R.id.teacher_text, "")
            } else {
                try {
                    val data = org.json.JSONObject(json)
                    val hasClass = data.optBoolean("hasClass", false)

                    if (hasClass) {
                        views.setTextViewText(R.id.label_text, data.optString("label", "接下来"))
                        views.setTextViewText(R.id.class_name_text, data.optString("className", ""))
                        views.setTextViewText(R.id.time_text, data.optString("timeRange", ""))
                        views.setTextViewText(R.id.location_text, data.optString("location", ""))
                        views.setTextViewText(R.id.teacher_text, data.optString("teacher", ""))
                    } else {
                        views.setTextViewText(R.id.label_text, "")
                        views.setTextViewText(R.id.class_name_text, context.getString(R.string.widget_label_no_class))
                        views.setTextViewText(R.id.time_text, "")
                        views.setTextViewText(R.id.location_text, "")
                        views.setTextViewText(R.id.teacher_text, "")
                    }
                } catch (e: Exception) {
                    views.setTextViewText(R.id.label_text, "")
                    views.setTextViewText(R.id.class_name_text, context.getString(R.string.widget_label_no_class))
                    views.setTextViewText(R.id.time_text, "")
                    views.setTextViewText(R.id.location_text, "")
                    views.setTextViewText(R.id.teacher_text, "")
                }
            }

            // Tap to open app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            return views
        }

        private fun getMonetAccentColor(context: Context): Int {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Try accent1_500 first, fallback to accent2_500, then accent3_500
                for (resId in listOf(
                    android.R.color.system_accent1_500,
                    android.R.color.system_accent2_500,
                    android.R.color.system_accent3_500,
                )) {
                    try {
                        return context.getColor(resId)
                    } catch (_: Exception) { }
                }
            }
            return context.getColor(R.color.widget_accent)
        }

        private fun getMonetColor(context: Context, resId: Int): Int? {
            return try {
                context.getColor(resId)
            } catch (_: Exception) {
                null
            }
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
