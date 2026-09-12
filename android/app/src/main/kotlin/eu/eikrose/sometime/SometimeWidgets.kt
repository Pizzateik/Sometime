package eu.eikrose.sometime

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.RemoteViews
import android.widget.ScrollView
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import kotlin.math.roundToInt

internal data class WidgetPalette(
    val background: Int,
    val ink: Int,
    val text: Int,
    val secondary: Int,
    val outline: Int,
    val primary: Int,
    val onPrimary: Int,
    val control: Int,
)

private data class WidgetGroup(
    val id: String,
    val label: String,
    val tasks: List<JSONObject>,
)

internal data class WidgetCollectionItem(
    val kind: Kind,
    val stableId: Long,
    val groupId: String = "",
    val spaceId: String = "",
    val label: String = "",
    val task: JSONObject? = null,
    val dense: Boolean = false,
    val descriptionLines: Int = 1,
    val showTime: Boolean = false,
    val emptyMessage: String = "",
) {
    enum class Kind { DIVIDER, HEADING, TASK, EMPTY }

    fun viewType(): Int = when (kind) {
        Kind.DIVIDER -> if (dense) 0 else 1
        Kind.HEADING -> if (dense) 2 else 3
        Kind.TASK -> {
            val hasDescription = task?.optString("description")?.trim()?.isNotEmpty() == true
            when {
                !hasDescription && dense -> 4
                !hasDescription -> 5
                descriptionLines == 2 -> 7
                else -> 6
            }
        }
        Kind.EMPTY -> 8
    }
}

internal data class WidgetStrings(
    val openSpace: (String) -> String,
    val createTask: String,
    val categoryLabels: Map<String, String>,
    val completeTask: (String) -> String,
    val openFirst: String,
    val nothingHere: String,
    val space: String,
    val selectSpace: String,
    val category: String,
    val selectCategory: String,
    val addWidget: String,
    val configurationFirst: String,
    val categoryNames: List<String>,
)

object SometimeWidgets {
    private lateinit var channel: MethodChannel
    private var launch: Map<String, Any?>? = null

    fun prefs(context: Context) =
        context.getSharedPreferences("sometime.widgets", Context.MODE_PRIVATE)

    fun snapshot(context: Context): JSONObject = runCatching {
        JSONObject(prefs(context).getString("snapshot", "{}") ?: "{}")
    }.getOrDefault(JSONObject())

    internal fun widgetStrings(context: Context, data: JSONObject): WidgetStrings {
        val systemTag = context.resources.configuration.locales[0].toLanguageTag()
        val tag = if (data.optString("languageMode") == "system") {
            systemTag
        } else {
            data.optString("language", systemTag)
        }
        val resolvedTag = when {
            tag.equals("pt-BR", ignoreCase = true) -> "pt-BR"
            tag.startsWith("de", ignoreCase = true) -> "de"
            tag.startsWith("es", ignoreCase = true) -> "es"
            tag.startsWith("fr", ignoreCase = true) -> "fr"
            tag.startsWith("ja", ignoreCase = true) -> "ja"
            else -> "en"
        }
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(resolvedTag))
        val resources = context.createConfigurationContext(configuration).resources
        fun string(id: Int) = resources.getString(id)
        fun string(id: Int, value: String) = resources.getString(id, value)
        return WidgetStrings(
            openSpace = { string(R.string.widget_open_space, it) },
            createTask = string(R.string.widget_create_task),
            categoryLabels = mapOf(
                "today" to string(R.string.widget_today),
                "soon" to string(R.string.widget_soon),
                "someday" to string(R.string.widget_someday),
            ),
            completeTask = { string(R.string.widget_complete_task, it) },
            openFirst = string(R.string.widget_open_first),
            nothingHere = string(R.string.widget_nothing_here),
            space = string(R.string.widget_space),
            selectSpace = string(R.string.widget_select_space),
            category = string(R.string.widget_category),
            selectCategory = string(R.string.widget_select_category),
            addWidget = string(R.string.widget_add),
            configurationFirst = string(R.string.widget_configuration_first),
            categoryNames = listOf(
                string(R.string.widget_category_today),
                string(R.string.widget_category_soon),
                string(R.string.widget_category_someday),
                string(R.string.widget_category_all),
            ),
        )
    }

    fun attach(context: Context, engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "sometime/widgets")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    val source = call.arguments as String
                    JSONObject(source)
                    if (!prefs(context).edit().putString("snapshot", source).commit()) {
                        result.error("storage", "The widget data could not be saved.", null)
                    } else {
                        updateAll(context)
                        result.success(null)
                    }
                }
                "launch" -> {
                    result.success(launch)
                    launch = null
                }
                else -> result.notImplemented()
            }
        }
    }

    fun receive(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != "sometime" || uri.host != "widget") return
        launch = mapOf(
            "space" to uri.getQueryParameter("space"),
            "task" to uri.getQueryParameter("task"),
            "category" to uri.getQueryParameter("category"),
            "create" to (uri.getQueryParameter("create") == "true"),
        )
        channel.invokeMethod("open", null)
    }

    private fun widgetUri(
        space: String,
        task: String? = null,
        category: String = "today",
        create: Boolean = false,
    ): Uri.Builder {
        val uri = Uri.Builder()
            .scheme("sometime")
            .authority("widget")
            .appendQueryParameter("space", space)
            .appendQueryParameter("category", category)
            .appendQueryParameter("create", create.toString())
        if (task != null) uri.appendQueryParameter("task", task)
        return uri
    }

    private fun pendingIntentCode(widgetId: Int, purpose: String): Int =
        (31 * widgetId + purpose.hashCode()) and 0x7fffffff

    private fun openTemplate(context: Context, widgetId: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            pendingIntentCode(widgetId, "collection-open"),
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun open(
        context: Context,
        widgetId: Int,
        space: String,
        task: String? = null,
        category: String = "today",
        create: Boolean = false,
        requestCode: Int = widgetId,
    ): PendingIntent {
        return PendingIntent.getActivity(
            context,
            requestCode,
            Intent(context, MainActivity::class.java)
                .setData(widgetUri(space, task, category, create).build())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun collectionIntent(
        context: Context,
        widgetId: Int,
        width: Float,
        height: Float,
    ): Intent = Intent(context, SometimeWidgetRemoteViewsService::class.java).apply {
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        putExtra("width", width)
        putExtra("height", height)
        data = Uri.parse("sometime://widget-collection/$widgetId/${width.toInt()}/${height.toInt()}")
    }

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in listOf(SmallSometimeWidget::class.java, MediumSometimeWidget::class.java)) {
            for (id in manager.getAppWidgetIds(ComponentName(context, provider))) update(context, id)
        }
        scheduleMidnight(context)
    }

    private fun scheduleMidnight(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val exists = listOf(SmallSometimeWidget::class.java, MediumSometimeWidget::class.java).any {
            manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty()
        }
        val pending = PendingIntent.getBroadcast(
            context,
            490,
            Intent(context, SmallSometimeWidget::class.java).setAction("sometime.midnight"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarm = context.getSystemService(AlarmManager::class.java)
        if (!exists) {
            alarm.cancel(pending)
            return
        }
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        alarm.set(AlarmManager.RTC, next.timeInMillis, pending)
    }

    private fun isDark(context: Context, data: JSONObject): Boolean = when (data.optString("mode")) {
        "dark" -> true
        "light" -> false
        else -> context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
    }

    private fun systemColor(context: Context, name: String, fallback: Int): Int {
        if (Build.VERSION.SDK_INT < 31) return fallback
        val id = context.resources.getIdentifier(name, "color", "android")
        return if (id == 0) fallback else context.getColor(id)
    }

    internal fun palette(context: Context, data: JSONObject): WidgetPalette {
        val dark = isDark(context, data)
        val defaults = if (dark) {
            WidgetPalette(
                Color.rgb(18, 18, 18), Color.WHITE, Color.rgb(239, 239, 234),
                Color.rgb(169, 170, 164), Color.rgb(119, 122, 115), Color.WHITE,
                Color.BLACK, Color.rgb(28, 28, 28),
            )
        } else {
            WidgetPalette(
                Color.rgb(250, 250, 248), Color.BLACK, Color.rgb(52, 56, 52),
                Color.rgb(105, 109, 102), Color.rgb(146, 150, 142), Color.BLACK,
                Color.WHITE, Color.WHITE,
            )
        }
        val saved = data.optJSONObject("theme")
            ?.optJSONObject(if (dark) "dark" else "light")
        var result = WidgetPalette(
            saved?.optLong("background", defaults.background.toLong())?.toInt() ?: defaults.background,
            saved?.optLong("ink", defaults.ink.toLong())?.toInt() ?: defaults.ink,
            saved?.optLong("text", defaults.text.toLong())?.toInt() ?: defaults.text,
            saved?.optLong("secondary", defaults.secondary.toLong())?.toInt() ?: defaults.secondary,
            saved?.optLong("outline", defaults.outline.toLong())?.toInt() ?: defaults.outline,
            saved?.optLong("primary", defaults.primary.toLong())?.toInt() ?: defaults.primary,
            saved?.optLong("onPrimary", defaults.onPrimary.toLong())?.toInt() ?: defaults.onPrimary,
            saved?.optLong("control", defaults.control.toLong())?.toInt() ?: defaults.control,
        )
        if (data.optString("style") == "materialYou" &&
            data.optString("colorSource") == "system" && Build.VERSION.SDK_INT >= 31
        ) {
            result = if (dark) {
                result.copy(
                    background = systemColor(context, "system_neutral1_900", result.background),
                    ink = systemColor(context, "system_neutral1_50", result.ink),
                    text = systemColor(context, "system_neutral1_100", result.text),
                    secondary = systemColor(context, "system_neutral2_200", result.secondary),
                    outline = systemColor(context, "system_neutral2_500", result.outline),
                    primary = systemColor(context, "system_accent1_200", result.primary),
                    onPrimary = systemColor(context, "system_accent1_800", result.onPrimary),
                    control = systemColor(context, "system_neutral1_800", result.control),
                )
            } else {
                result.copy(
                    background = systemColor(context, "system_neutral1_10", result.background),
                    ink = systemColor(context, "system_neutral1_900", result.ink),
                    text = systemColor(context, "system_neutral1_800", result.text),
                    secondary = systemColor(context, "system_neutral2_700", result.secondary),
                    outline = systemColor(context, "system_neutral2_500", result.outline),
                    primary = systemColor(context, "system_accent1_600", result.primary),
                    onPrimary = systemColor(context, "system_accent1_0", result.onPrimary),
                    control = systemColor(context, "system_neutral1_50", result.control),
                )
            }
        }
        return result
    }

    fun update(context: Context, widgetId: Int) {
        val manager = AppWidgetManager.getInstance(context)
        val data = snapshot(context)
        val spacesJson = data.optJSONArray("spaces")
        val spaces = (0 until (spacesJson?.length() ?: 0)).mapNotNull {
            spacesJson?.optJSONObject(it)
        }
        val configuredSpace = prefs(context).getString("space:$widgetId", "default-space")
            ?: "default-space"
        val space = spaces.firstOrNull { it.optString("id") == configuredSpace }
            ?: spaces.firstOrNull()
        val spaceId = space?.optString("id") ?: "default-space"
        if (space != null && configuredSpace != spaceId) {
            prefs(context).edit().putString("space:$widgetId", spaceId).apply()
        }
        val savedCategory = prefs(context).getString("category:$widgetId", "today") ?: "today"
        val category = savedCategory.takeIf { it in listOf("today", "soon", "someday", "all") }
            ?: "today"
        if (category != savedCategory) {
            prefs(context).edit().putString("category:$widgetId", category).apply()
        }
        val strings = widgetStrings(context, data)
        val options = manager.getAppWidgetOptions(widgetId)
        if (Build.VERSION.SDK_INT >= 31) {
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                val responsive = linkedMapOf<SizeF, RemoteViews>()
                for (size in sizes.distinct()) {
                    responsive[size] = buildViews(
                        context, widgetId, size.width, size.height, data, space,
                        spaceId, category, strings,
                    )
                }
                manager.updateAppWidget(widgetId, RemoteViews(responsive))
                manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_rows)
                return
            }
        }
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180).toFloat()
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180).toFloat()
        manager.updateAppWidget(
            widgetId,
            buildViews(
                context, widgetId, width, height, data, space, spaceId,
                category, strings,
            ),
        )
        manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_rows)
    }

    private fun buildViews(
        context: Context,
        widgetId: Int,
        width: Float,
        height: Float,
        data: JSONObject,
        space: JSONObject?,
        spaceId: String,
        category: String,
        strings: WidgetStrings,
    ): RemoteViews {
        val palette = palette(context, data)
        val compact = width < 170f || height < 150f
        val denseAll = category == "all" && height >= 220f && height < 300f
        val padding = if (compact || denseAll) 12 else 16
        val brandHeight = if (height < 105f) 0 else 26
        val showPlus = width >= 145f && height >= 145f
        val views = RemoteViews(context.packageName, R.layout.sometime_widget)
        views.setInt(R.id.widget_surface, "setColorFilter", palette.background)
        val paddingPixels = (padding * context.resources.displayMetrics.density).roundToInt()
        views.setViewPadding(
            R.id.widget_content,
            paddingPixels,
            paddingPixels,
            paddingPixels,
            paddingPixels,
        )
        views.setViewVisibility(R.id.widget_brand, if (brandHeight > 0) View.VISIBLE else View.GONE)
        views.setTextColor(R.id.widget_brand, palette.ink)
        views.setTextViewTextSize(
            R.id.widget_brand,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            if (compact) 14f else 16f,
        )
        val spaceName = space?.optString("name", "Sometime") ?: "Sometime"
        views.setTextViewText(R.id.widget_brand, spaceName)
        views.setContentDescription(
            R.id.widget_brand,
            strings.openSpace(spaceName),
        )
        views.setOnClickPendingIntent(
            R.id.widget_brand,
            open(
                context,
                widgetId,
                spaceId,
                category = category,
                requestCode = pendingIntentCode(widgetId, "brand"),
            ),
        )
        views.setViewVisibility(R.id.widget_plus_row, if (showPlus) View.VISIBLE else View.GONE)
        views.setInt(R.id.widget_plus_surface, "setColorFilter", palette.primary)
        views.setInt(R.id.widget_plus_icon, "setColorFilter", palette.onPrimary)
        views.setContentDescription(
            R.id.widget_plus,
            strings.createTask,
        )
        views.setOnClickPendingIntent(
            R.id.widget_plus,
            open(
                context,
                widgetId,
                spaceId,
                category = category,
                create = true,
                requestCode = pendingIntentCode(widgetId, "plus"),
            ),
        )
        views.setRemoteAdapter(
            R.id.widget_rows,
            collectionIntent(context, widgetId, width, height),
        )
        views.setPendingIntentTemplate(R.id.widget_rows, openTemplate(context, widgetId))
        return views
    }

    internal fun collectionItems(
        context: Context,
        widgetId: Int,
        width: Float,
        height: Float,
        snapshotData: JSONObject = snapshot(context),
    ): List<WidgetCollectionItem> {
        val data = snapshotData
        val spacesJson = data.optJSONArray("spaces")
        val spaces = (0 until (spacesJson?.length() ?: 0)).mapNotNull {
            spacesJson?.optJSONObject(it)
        }
        val configuredSpace = prefs(context).getString("space:$widgetId", "default-space")
            ?: "default-space"
        val space = spaces.firstOrNull { it.optString("id") == configuredSpace }
            ?: spaces.firstOrNull()
        val spaceId = space?.optString("id") ?: "default-space"
        val savedCategory = prefs(context).getString("category:$widgetId", "today") ?: "today"
        val category = savedCategory.takeIf { it in listOf("today", "soon", "someday", "all") }
            ?: "today"
        val strings = widgetStrings(context, data)
        val denseAll = category == "all" && height >= 220f && height < 300f
        val showHeadings = category == "all" || height >= 165f
        val descriptionLines = if (width >= 220f && height >= 300f) 2 else 1
        val showTime = width >= 270f
        val labels = strings.categoryLabels
        val ids = if (category == "all") listOf("today", "soon", "someday")
        else listOf(category)
        val tasks = availableTasks(space)
        val groups = ids.map { id ->
            WidgetGroup(
                id,
                labels[id] ?: id.uppercase(),
                tasks.filter { it.optString("category") == id },
            )
        }.filter { it.tasks.isNotEmpty() }
        val items = mutableListOf<WidgetCollectionItem>()
        for ((index, group) in groups.withIndex()) {
            if (index > 0) {
                items += WidgetCollectionItem(
                    kind = WidgetCollectionItem.Kind.DIVIDER,
                    stableId = collectionStableId("divider:$spaceId:${group.id}"),
                    groupId = group.id,
                    spaceId = spaceId,
                    dense = denseAll,
                )
            }
            if (showHeadings) {
                items += WidgetCollectionItem(
                    kind = WidgetCollectionItem.Kind.HEADING,
                    stableId = collectionStableId("heading:$spaceId:${group.id}"),
                    groupId = group.id,
                    spaceId = spaceId,
                    label = group.label,
                    dense = denseAll,
                )
            }
            for ((taskIndex, task) in group.tasks.withIndex()) {
                val taskId = task.optString("id")
                items += WidgetCollectionItem(
                    kind = WidgetCollectionItem.Kind.TASK,
                    stableId = collectionStableId(
                        "task:$spaceId:${group.id}:$taskId:$taskIndex",
                    ),
                    groupId = group.id,
                    spaceId = spaceId,
                    task = task,
                    dense = denseAll,
                    descriptionLines = descriptionLines,
                    showTime = showTime,
                )
            }
        }
        if (items.isEmpty()) {
            items += WidgetCollectionItem(
                kind = WidgetCollectionItem.Kind.EMPTY,
                stableId = collectionStableId("empty:$spaceId:$category"),
                spaceId = spaceId,
                emptyMessage = if (space == null) strings.openFirst else strings.nothingHere,
            )
        }
        return items
    }

    internal fun collectionItemViews(
        context: Context,
        widgetId: Int,
        item: WidgetCollectionItem,
        data: JSONObject = snapshot(context),
    ): RemoteViews {
        val palette = palette(context, data)
        val strings = widgetStrings(context, data)
        return when (item.kind) {
            WidgetCollectionItem.Kind.DIVIDER -> RemoteViews(
                context.packageName,
                if (item.dense) R.layout.sometime_widget_divider_dense
                else R.layout.sometime_widget_divider,
            ).also { it.setInt(R.id.widget_divider, "setColorFilter", palette.outline) }
            WidgetCollectionItem.Kind.HEADING -> RemoteViews(
                context.packageName,
                if (item.dense) R.layout.sometime_widget_heading_dense
                else R.layout.sometime_widget_heading,
            ).also {
                it.setTextViewText(R.id.widget_heading, item.label)
                it.setTextColor(R.id.widget_heading, palette.secondary)
            }
            WidgetCollectionItem.Kind.EMPTY -> RemoteViews(
                context.packageName,
                R.layout.sometime_widget_empty,
            ).also {
                it.setTextViewText(R.id.widget_empty, item.emptyMessage)
                it.setTextColor(R.id.widget_empty, palette.secondary)
            }
            WidgetCollectionItem.Kind.TASK -> taskItemViews(context, widgetId, item, palette, strings)
        }
    }

    private fun taskItemViews(
        context: Context,
        widgetId: Int,
        item: WidgetCollectionItem,
        palette: WidgetPalette,
        strings: WidgetStrings,
    ): RemoteViews {
        val task = requireNotNull(item.task)
        val description = task.optString("description").trim()
        val withDescription = description.isNotEmpty()
        val layout = when {
            withDescription && item.descriptionLines == 2 ->
                R.layout.sometime_widget_task_description_two_lines
            withDescription -> R.layout.sometime_widget_task_description
            item.dense -> R.layout.sometime_widget_task_dense
            else -> R.layout.sometime_widget_task
        }
        val row = RemoteViews(context.packageName, layout)
        val title = task.optString("title")
        val taskId = task.optString("id")
        row.setTextViewText(R.id.widget_title, title)
        row.setTextColor(R.id.widget_title, palette.text)
        row.setInt(R.id.widget_complete, "setColorFilter", palette.outline)
        row.setContentDescription(R.id.widget_complete, strings.completeTask(title))
        row.setContentDescription(
            R.id.widget_task,
            listOf(title, description.takeIf { withDescription })
                .filterNotNull().joinToString(". "),
        )
        row.setOnClickFillInIntent(
            R.id.widget_task,
            Intent().setData(widgetUri(item.spaceId, taskId, item.groupId).build()),
        )
        val complete = Intent(context, TaskNotificationReceiver::class.java)
            .setAction("complete")
            .setData(Uri.parse("sometime://complete/${Uri.encode(taskId)}"))
            .putExtra("space", item.spaceId)
            .putExtra("task", taskId)
        row.setOnClickPendingIntent(
            R.id.widget_complete,
            PendingIntent.getBroadcast(
                context,
                pendingIntentCode(widgetId, "complete:${item.spaceId}:$taskId"),
                complete,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        val minutes = task.optInt("minutes", -1)
        row.setTextViewText(
            R.id.widget_time,
            if (item.showTime && minutes >= 0) "%02d:%02d".format(minutes / 60, minutes % 60)
            else "",
        )
        row.setTextColor(R.id.widget_time, palette.secondary)
        if (withDescription) {
            row.setTextViewText(R.id.widget_description, description)
            row.setTextColor(R.id.widget_description, palette.secondary)
        }
        return row
    }

    private fun collectionStableId(value: String): Long = value.hashCode().toLong()

    private fun availableTasks(space: JSONObject?): List<JSONObject> {
        val tasksJson = space?.optJSONArray("tasks")
        val now = System.currentTimeMillis()
        return (0 until (tasksJson?.length() ?: 0)).mapNotNull {
            tasksJson?.optJSONObject(it)
        }.filter { task ->
            val available = task.optJSONArray("availableDate")?.let { parts ->
                Calendar.getInstance().apply {
                    clear()
                    set(parts.optInt(0), parts.optInt(1) - 1, parts.optInt(2))
                }.timeInMillis
            } ?: task.optLong("available", 0)
            available <= now
        }
    }
}

open class SmallSometimeWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        SometimeWidgets.updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            SometimeWidgets.updateAll(context)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        SometimeWidgets.update(context, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val edit = SometimeWidgets.prefs(context).edit()
        for (id in ids) {
            edit.remove("space:$id")
            edit.remove("category:$id")
        }
        edit.apply()
    }
}

class MediumSometimeWidget : SmallSometimeWidget()

class SometimeWidgetConfiguration : Activity() {
    private lateinit var palette: WidgetPalette
    private val density by lazy { resources.displayMetrics.density }

    private fun dp(value: Int) = (value * density).roundToInt()

    private fun typeface(weight: Int): Typeface {
        val base = if (Build.VERSION.SDK_INT >= 26) resources.getFont(R.font.geist)
        else Typeface.create("sans-serif", Typeface.NORMAL)
        return if (Build.VERSION.SDK_INT >= 28) Typeface.create(base, weight, false)
        else Typeface.create(base, if (weight >= 600) Typeface.BOLD else Typeface.NORMAL)
    }

    private fun shape(color: Int, strokeColor: Int? = null): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(12).toFloat()
            if (strokeColor != null) setStroke(dp(1), strokeColor)
        }

    private fun controlBackground(color: Int, strokeColor: Int? = null) =
        RippleDrawable(
            ColorStateList.valueOf(
                Color.argb(
                    20, Color.red(palette.ink), Color.green(palette.ink), Color.blue(palette.ink),
                ),
            ),
            shape(color, strokeColor),
            null,
        )

    private fun text(
        value: String,
        size: Float,
        weight: Int,
        color: Int,
    ) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        typeface = typeface(weight)
        gravity = Gravity.CENTER
        includeFontPadding = false
    }

    private fun showOptions(
        anchor: View,
        items: List<String>,
        onSelected: (Int) -> Unit,
    ) {
        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = shape(palette.control, palette.outline)
            setPadding(0, dp(4), 0, dp(4))
        }
        val popup = PopupWindow(
            list,
            anchor.width,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            true,
        ).apply {
            isOutsideTouchable = true
            elevation = dp(8).toFloat()
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        }
        items.forEachIndexed { index, item ->
            val row = text(item, 15f, 550, palette.text).apply {
                minHeight = dp(48)
                isClickable = true
                isFocusable = true
                contentDescription = item
                background = RippleDrawable(
                    ColorStateList.valueOf(
                        Color.argb(
                            20,
                            Color.red(palette.ink),
                            Color.green(palette.ink),
                            Color.blue(palette.ink),
                        ),
                    ),
                    ColorDrawable(Color.TRANSPARENT),
                    null,
                )
                setOnClickListener {
                    onSelected(index)
                    popup.dismiss()
                }
            }
            list.addView(
                row,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(48),
                ),
            )
        }
        popup.showAsDropDown(anchor, 0, dp(4))
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setResult(RESULT_CANCELED)
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val data = SometimeWidgets.snapshot(this)
        palette = SometimeWidgets.palette(this, data)
        window.statusBarColor = palette.background
        window.navigationBarColor = palette.background
        if (Color.luminance(palette.background) >= 0.35) {
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        }
        val strings = SometimeWidgets.widgetStrings(this, data)
        val rawSpaces = data.optJSONArray("spaces")
        val spaces = (0 until (rawSpaces?.length() ?: 0)).mapNotNull {
            rawSpaces?.optJSONObject(it)
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(palette.background)
        }
        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(44), dp(24), dp(32))
        }
        scroll.addView(
            page,
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        val width = minOf(dp(420), resources.displayMetrics.widthPixels - dp(48))
        fun params(height: Int = ViewGroup.LayoutParams.WRAP_CONTENT, top: Int = 0) =
            LinearLayout.LayoutParams(width, height).apply { topMargin = dp(top) }

        page.addView(text("Sometime", 28f, 700, palette.ink), params(top = 4))
        if (spaces.isEmpty()) {
            page.addView(text(strings.configurationFirst, 14f, 500, palette.secondary), params(top = 40))
            setContentView(scroll)
            return
        }

        var selectedSpace = spaces.indexOfFirst {
            it.optString("id") == SometimeWidgets.prefs(this)
                .getString("space:$widgetId", "default-space")
        }.coerceAtLeast(0)
        val categoryIds = listOf("today", "soon", "someday", "all")
        val categoryNames = strings.categoryNames
        var selectedCategory = categoryIds.indexOf(
            SometimeWidgets.prefs(this).getString("category:$widgetId", "today"),
        ).coerceAtLeast(0)

        fun addLabel(value: String, top: Int) {
            page.addView(text(value, 13f, 600, palette.secondary), params(top = top))
        }

        fun selector(value: String, description: String): TextView =
            text(value, 16f, 600, palette.text).apply {
                minHeight = dp(52)
                setPadding(dp(16), dp(8), dp(16), dp(8))
                background = controlBackground(palette.control, palette.outline)
                contentDescription = description
                isClickable = true
                isFocusable = true
            }

        addLabel(strings.space, 38)
        val spaceSelector = selector(
            spaces[selectedSpace].optString("name"),
            strings.selectSpace,
        )
        page.addView(spaceSelector, params(dp(52), 10))
        spaceSelector.setOnClickListener { anchor ->
            showOptions(anchor, spaces.map { it.optString("name") }) { index ->
                selectedSpace = index
                spaceSelector.text = spaces[selectedSpace].optString("name")
            }
        }

        addLabel(strings.category, 26)
        val categorySelector = selector(
            categoryNames[selectedCategory],
            strings.selectCategory,
        )
        page.addView(categorySelector, params(dp(52), 10))
        categorySelector.setOnClickListener { anchor ->
            showOptions(anchor, categoryNames) { index ->
                selectedCategory = index
                categorySelector.text = categoryNames[selectedCategory]
            }
        }

        val actionLabel = strings.addWidget
        val action = text(actionLabel, 16f, 650, palette.onPrimary).apply {
            minHeight = dp(52)
            setPadding(dp(20), dp(10), dp(20), dp(10))
            background = controlBackground(palette.primary)
            contentDescription = actionLabel
            isClickable = true
            isFocusable = true
            setOnClickListener {
                SometimeWidgets.prefs(this@SometimeWidgetConfiguration).edit()
                    .putString("space:$widgetId", spaces[selectedSpace].optString("id"))
                    .putString("category:$widgetId", categoryIds[selectedCategory])
                    .commit()
                SometimeWidgets.update(this@SometimeWidgetConfiguration, widgetId)
                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                )
                finish()
            }
        }
        page.addView(action, params(dp(52), 36))
        setContentView(scroll)
    }
}
