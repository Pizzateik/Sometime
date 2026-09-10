package eu.eikrose.sometime

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject

class SometimeWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        SometimeWidgetRemoteViewsFactory(applicationContext, intent)
}

private class SometimeWidgetRemoteViewsFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {
    private val widgetId = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID,
    )
    private val width = intent.getFloatExtra("width", 180f)
    private val height = intent.getFloatExtra("height", 180f)
    private var items: List<WidgetCollectionItem> = emptyList()
    private var snapshot = JSONObject()

    override fun onCreate() = loadItems()

    override fun onDataSetChanged() = loadItems()

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position !in items.indices) return null
        return SometimeWidgets.collectionItemViews(context, widgetId, items[position], snapshot)
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 9

    override fun getItemId(position: Int): Long = items.getOrNull(position)?.stableId ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun loadItems() {
        snapshot = SometimeWidgets.snapshot(context)
        items = SometimeWidgets.collectionItems(context, widgetId, width, height, snapshot)
    }
}
