package com.lyme.beikenext

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class UpcomingClassWidget : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "com.lyme.beikenext.widget"
        private const val KEY_LEGACY = "upcoming_class_data"
        private const val KEY_FULL_DATA = "curriculum_full_data"
        private const val REFRESH_INTERVAL_MS = 5 * 60 * 1000L
        private const val ACTION_AUTO_REFRESH = "com.lyme.beikenext.AUTO_REFRESH"

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

        fun saveFullData(context: Context, json: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_FULL_DATA, json).apply()
        }

        fun scheduleAutoRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, UpcomingClassWidget::class.java).apply {
                action = ACTION_AUTO_REFRESH
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

            val triggerAt = SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MS
            val info = AlarmManager.AlarmClockInfo(triggerAt, pendingIntent)
            alarmManager.setAlarmClock(info, pendingIntent)
        }

        fun cancelAutoRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, UpcomingClassWidget::class.java).apply {
                action = ACTION_AUTO_REFRESH
            }
            val flags = PendingIntent.FLAG_NO_CREATE or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }

        private fun formatTime(minuteOfDay: Int): String {
            val h = minuteOfDay / 60
            val m = minuteOfDay % 60
            return "${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}"
        }

        private fun convertToMondayBased(javaDayOfWeek: Int): Int {
            return if (javaDayOfWeek == java.util.Calendar.SUNDAY) 7 else javaDayOfWeek - 1
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_class)
            fillContent(context, views)
            return views
        }

        private fun fillContent(context: Context, views: RemoteViews) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_FULL_DATA, null)

            if (json == null) {
                views.setInt(R.id.label_text, "setVisibility", 0x00000008)
                views.setInt(R.id.time_text, "setVisibility", 0x00000008)
                views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
                views.setTextViewText(R.id.class_name_text, "等待数据同步…")
                attachClickIntent(context, views)
                return
            }

            try {
                val data = JSONObject(json)
                if (!data.optBoolean("hasData", false)) {
                    views.setInt(R.id.label_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.time_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
                    views.setTextViewText(R.id.class_name_text, "课表未加载")
                    attachClickIntent(context, views)
                    return
                }

                val calendar = java.util.Calendar.getInstance()
                val todayYear = calendar.get(java.util.Calendar.YEAR)
                val todayMonth = calendar.get(java.util.Calendar.MONTH) + 1
                val todayDay = calendar.get(java.util.Calendar.DAY_OF_MONTH)
                val todayWeekday = convertToMondayBased(calendar.get(java.util.Calendar.DAY_OF_WEEK))

                // Find today's week index from calendar days
                var todayWeekIndex: Int? = null
                val calendarDays = data.optJSONArray("calendarDays")
                if (calendarDays != null) {
                    for (i in 0 until calendarDays.length()) {
                        val cd = calendarDays.getJSONObject(i)
                        if (cd.optInt("year") == todayYear &&
                            cd.optInt("month") == todayMonth &&
                            cd.optInt("day") == todayDay) {
                            todayWeekIndex = cd.getInt("weekIndex")
                            break
                        }
                    }
                }

                if (todayWeekIndex == null) {
                    views.setInt(R.id.label_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.time_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
                    views.setTextViewText(R.id.class_name_text, "课表数据未就绪")
                    attachClickIntent(context, views)
                    return
                }

                val allClasses = data.optJSONArray("allClasses") ?: run {
                    showNoClass(views, context, "课表数据异常", "")
                    return
                }
                val allPeriods = data.optJSONArray("allPeriods") ?: run {
                    showNoClass(views, context, "课表数据异常", "")
                    return
                }

                // Filter today's valid classes
                val todayClasses = mutableListOf<JSONObject>()
                for (i in 0 until allClasses.length()) {
                    val cls = allClasses.getJSONObject(i)
                    if (cls.optInt("day") != todayWeekday) continue
                    val weeks = cls.optJSONArray("weeks") ?: continue
                    for (j in 0 until weeks.length()) {
                        if (weeks.optInt(j) == todayWeekIndex) {
                            todayClasses.add(cls)
                            break
                        }
                    }
                }

                if (todayClasses.isEmpty()) {
                    val isWeekend = todayWeekday >= 6
                    showNoClass(views, context,
                        if (isWeekend) "周末愉快～" else "今日无课",
                        if (isWeekend) "" else "好好休息吧~")
                    return
                }

                // Compute start/end times for each class
                data class TimedClass(
                    val className: String,
                    val teacherName: String,
                    val locationName: String,
                    val startMinute: Int,
                    val endMinute: Int
                )

                val timedClasses = todayClasses.mapNotNull { cls ->
                    val majorId = cls.optInt("period")
                    var earliestStart = Int.MAX_VALUE
                    var latestEnd = Int.MIN_VALUE

                    for (i in 0 until allPeriods.length()) {
                        val period = allPeriods.getJSONObject(i)
                        if (period.optInt("majorId") != majorId) continue
                        val startStr = period.optString("minorStartTime")
                        val endStr = period.optString("minorEndTime")
                        if (startStr.isEmpty() || endStr.isEmpty()) continue

                        val sp = startStr.split(":")
                        val ep = endStr.split(":")
                        if (sp.size < 2 || ep.size < 2) continue
                        val sm = sp[0].toIntOrNull() ?: continue
                        val s = sm * 60 + (sp[1].toIntOrNull() ?: continue)
                        val em = ep[0].toIntOrNull() ?: continue
                        val e = em * 60 + (ep[1].toIntOrNull() ?: continue)

                        if (s < earliestStart) earliestStart = s
                        if (e > latestEnd) latestEnd = e
                    }

                    if (earliestStart == Int.MAX_VALUE) null
                    else TimedClass(
                        className = cls.optString("className", ""),
                        teacherName = cls.optString("teacherName", ""),
                        locationName = cls.optString("locationName", ""),
                        startMinute = earliestStart,
                        endMinute = latestEnd
                    )
                }.sortedBy { it.startMinute }

                if (timedClasses.isEmpty()) {
                    showNoClass(views, context, "今日无课", "好好休息吧~")
                    return
                }

                val nowMinute = calendar.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
                        calendar.get(java.util.Calendar.MINUTE)

                // Find ongoing or next class
                var currentClass: TimedClass? = null
                var nextClass: TimedClass? = null

                for (tc in timedClasses) {
                    if (nowMinute >= tc.startMinute && nowMinute < tc.endMinute) {
                        currentClass = tc
                    } else if (nowMinute < tc.startMinute && nextClass == null) {
                        nextClass = tc
                    }
                }

                val target = currentClass ?: nextClass
                if (target != null) {
                    val label = if (currentClass != null) "进行中" else "接下来"
                    val timeRange = if (currentClass != null) {
                        "进行中 - ${formatTime(target.endMinute)}"
                    } else {
                        "${formatTime(target.startMinute)} - ${formatTime(target.endMinute)}"
                    }

                    views.setInt(R.id.label_text, "setVisibility", 0x00000000)     // VISIBLE
                    views.setTextViewText(R.id.label_text, label)
                    views.setInt(R.id.time_text, "setVisibility", 0x00000000)      // VISIBLE
                    views.setInt(R.id.location_text, "setVisibility", 0x00000000)
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000000)
                    views.setTextViewText(R.id.class_name_text, target.className)
                    views.setTextViewText(R.id.time_text, timeRange)
                    views.setTextViewText(R.id.location_text, target.locationName)
                    views.setTextViewText(R.id.teacher_text, target.teacherName)
                } else {
                    views.setInt(R.id.label_text, "setVisibility", 0x00000008)     // GONE
                    views.setInt(R.id.time_text, "setVisibility", 0x00000008)      // GONE
                    views.setInt(R.id.location_text, "setVisibility", 0x00000008)
                    views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
                    views.setTextViewText(R.id.class_name_text, "今日课毕")
                }
                attachClickIntent(context, views)

            } catch (e: Exception) {
                showNoClass(views, context, "数据解析失败", "请打开App刷新")
            }
        }

        private fun showNoClass(views: RemoteViews, context: Context,
                                title: String, subtitle: String) {
            views.setInt(R.id.label_text, "setVisibility", 0x00000008)     // GONE
            views.setInt(R.id.time_text, "setVisibility", 0x00000008)      // GONE
            views.setInt(R.id.location_text, "setVisibility", 0x00000008)
            views.setInt(R.id.teacher_text, "setVisibility", 0x00000008)
            views.setTextViewText(R.id.class_name_text, title)
            attachClickIntent(context, views)
        }

        private fun attachClickIntent(context: Context, views: RemoteViews) {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pi)
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_AUTO_REFRESH -> {
                updateAllWidgets(context)
                scheduleAutoRefresh(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        scheduleAutoRefresh(context)
    }

    override fun onDisabled(context: Context) {
        cancelAutoRefresh(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
    }
}
