package eu.eikrose.sometime

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object AssistantTasks {
    private const val PREFS = "sometime.assistant"
    private const val PENDING = "pending"
    private var channel: MethodChannel? = null
    private var context: Context? = null

    fun attach(context: Context, engine: FlutterEngine) {
        this.context = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "sometime/assistant")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "pending" -> result.success(pending().map { entry ->
                    mapOf(
                        "id" to entry.optString("id"),
                        "title" to entry.optString("title"),
                        "category" to entry.optString("category").ifEmpty { null },
                        "date" to entry.optString("date").ifEmpty { null },
                        "time" to entry.optString("time").ifEmpty { null },
                    )
                })
                "ack" -> {
                    val id = call.arguments as? String
                    val remaining = pending().filter { it.optString("id") != id }
                    if (save(remaining)) result.success(null)
                    else result.error("storage", "The assistant request could not be acknowledged.", null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun receive(intent: Intent) {
        if (!intent.hasExtra("assistant_create")) return
        val title = intent.getStringExtra("assistant_title")?.trim().orEmpty()
        if (title.isEmpty()) {
            intent.removeExtra("assistant_create")
            return
        }
        val entry = JSONObject().put("id", UUID.randomUUID().toString()).put("title", title)
        for (name in listOf("category", "date", "time")) {
            intent.getStringExtra("assistant_$name")?.let { entry.put(name, it) }
        }
        if (save(pending() + entry)) {
            intent.removeExtra("assistant_create")
            channel?.invokeMethod("newTask", null)
        }
    }

    private fun pending(): List<JSONObject> {
        val app = context ?: return emptyList()
        val source = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(PENDING, "[]")
        val array = runCatching { JSONArray(source) }.getOrDefault(JSONArray())
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }

    private fun save(entries: List<JSONObject>): Boolean {
        val app = context ?: return false
        val array = JSONArray()
        entries.forEach { array.put(it) }
        return app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(PENDING, array.toString()).commit()
    }
}
