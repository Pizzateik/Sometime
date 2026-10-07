package de.eikrose.sometime

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object AppShortcuts {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "sometime/shortcuts")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "launch" -> {
                    val action = pending
                    pending = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun receive(intent: Intent) {
        val action = intent.getStringExtra("shortcut_action") ?: return
        intent.removeExtra("shortcut_action")
        if (action !in setOf("new_task", "new_routine", "someday")) return
        pending = action
        channel?.invokeMethod("open", null)
    }
}
