package com.littlebit0.dailycalendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

abstract class DailyBaseWidgetProvider : AppWidgetProvider() {
    abstract val layoutId: Int
    abstract val title: String
    abstract fun subtitle(now: Date): String

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle(Date()))
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun launchIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context,
            title.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class DailyMonthWidgetProvider : DailyBaseWidgetProvider() {
    override val layoutId = R.layout.widget_month
    override val title = "Daily 월간"

    override fun subtitle(now: Date): String {
        return SimpleDateFormat("yyyy년 M월", Locale.KOREA).format(now)
    }
}

class DailyTodayWidgetProvider : DailyBaseWidgetProvider() {
    override val layoutId = R.layout.widget_today
    override val title = "오늘 일정"

    override fun subtitle(now: Date): String {
        return SimpleDateFormat("M월 d일 E요일", Locale.KOREA).format(now)
    }
}

class DailyDdayWidgetProvider : DailyBaseWidgetProvider() {
    override val layoutId = R.layout.widget_dday
    override val title = "D-day"

    override fun subtitle(now: Date): String {
        return "중요한 날짜를 한눈에 확인"
    }
}
