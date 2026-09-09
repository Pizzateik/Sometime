package eu.eikrose.sometime

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.*
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.text.DateFormat
import java.util.Locale
import java.util.UUID

class SometimeApplication : Application() {
    lateinit var engine: FlutterEngine
    override fun onCreate() {
        super.onCreate()
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)
        engine = FlutterEngine(this)
        TaskNotifications.attach(this, engine)
        SometimeWidgets.attach(this, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
    }
}

object TaskNotifications {
    private const val STORE = "sometime.notifications"
    private const val REMINDERS = "reminders"
    private const val PINS = "pinned_tasks"
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    var activity: MainActivity? = null
    private var permissionResult: MethodChannel.Result? = null
    private val waiting = mutableListOf<BroadcastReceiver.PendingResult>()
    private fun prefs() = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun manager() = context.getSystemService(NotificationManager::class.java)
    private fun alarms() = context.getSystemService(AlarmManager::class.java)
    private fun plans() = runCatching { JSONArray(prefs().getString("plans", "[]")) }.getOrDefault(JSONArray())
    private fun events() = runCatching { JSONArray(prefs().getString("events", "[]")) }.getOrDefault(JSONArray())
    private fun allowed() = Build.VERSION.SDK_INT < 24 || manager().areNotificationsEnabled()

    fun attach(app: Context, engine: FlutterEngine) {
        context = app.applicationContext
        if (Build.VERSION.SDK_INT >= 26) {
            manager().createNotificationChannel(NotificationChannel(REMINDERS, "Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
            })
            manager().createNotificationChannel(NotificationChannel(PINS, "Pinned Tasks", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
            })
        }
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "sometime/notifications")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && !allowed() && !prefs().getBoolean("asked", false) && activity != null) {
                            prefs().edit().putBoolean("asked", true).commit()
                            permissionResult = result
                            activity!!.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 701)
                        } else result.success(allowed())
                    }
                    "settings" -> {
                        if (Build.VERSION.SDK_INT >= 31 && allowed() && !alarms().canScheduleExactAlarms()) {
                            activity?.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}")))
                        } else activity?.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
                        result.success(null)
                    }
                    "events" -> result.success((0 until events().length()).map { jsonMap(events().getJSONObject(it)) })
                    "ack" -> {
                        val remaining = JSONArray()
                        val queue = events()
                        for (i in 0 until queue.length()) if (queue.getJSONObject(i).getString("id") != call.arguments) remaining.put(queue.getJSONObject(i))
                        prefs().edit().putString("events", remaining.toString()).commit()

                        result.success(null)
                    }
                    "sync" -> {
                        if (events().length() > 0) result.success(mapOf("retry" to true))
                        else {
                            val next = JSONArray(call.arguments as List<*>)
                            val old = plans()
                            val nextIds = (0 until next.length()).map { next.getJSONObject(it).getString("id") }.toSet()
                            for (i in 0 until old.length()) {
                                val spec = old.getJSONObject(i)
                                if (spec.getString("id") !in nextIds) cancel(spec)
                            }
                            prefs().edit().putString("plans", next.toString()).commit()
                            for (i in 0 until next.length()) reconcile(next.getJSONObject(i))
                            waiting.forEach { it.finish() }
                            waiting.clear()
                            result.success(mapOf("allowed" to allowed(), "warning" to
                                if (Build.VERSION.SDK_INT >= 31 && !alarms().canScheduleExactAlarms() &&
                                    (0 until next.length()).any { next.getJSONObject(it).optString("reminder", "none") != "none" })
                                    "Android may delay reminders. Allow exact alarms in system settings." else null))
                        }
                    }
                    "removeSpace" -> {
                        removeSpace(call.arguments as String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("notifications", error.message, null) }
        }
    }

    fun permissionReply() { permissionResult?.success(allowed()); permissionResult = null }
    private fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
        json.get(key).let { if (it == JSONObject.NULL) null else it }
    }

    // Persist allocated IDs to avoid hash collisions and keep updates stable.
    private fun notificationId(task: String): Int {
        val key = "id:$task"
        val existing = prefs().getInt(key, 0)
        if (existing != 0) return existing
        val next = prefs().getInt("nextId", 0) + 1
        prefs().edit().putInt(key, next).putInt("nextId", next).commit()
        return next
    }

    private fun intent(spec: JSONObject, action: String): Intent = Intent(context, TaskNotificationReceiver::class.java)
        .setAction(action).setData(Uri.parse("sometime://notification/${Uri.encode(spec.getString("id"))}/$action"))
        .putExtra("task", spec.getString("id")).putExtra("space", spec.getString("space"))
    private fun pending(spec: JSONObject, action: String) = PendingIntent.getBroadcast(context, 0, intent(spec, action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(spec: JSONObject) {
        alarms().cancel(pending(spec, "remind"))
        alarms().cancel(pending(spec, "activate"))
        manager().cancel(notificationId(spec.getString("id")))
    }
    private fun removeSpace(space: String) {
        val remainingPlans = JSONArray()
        val currentPlans = plans()
        val removedTaskIds = mutableListOf<String>()
        for (i in 0 until currentPlans.length()) {
            val spec = currentPlans.getJSONObject(i)
            if (spec.optString("space") == space) {
                cancel(spec)
                removedTaskIds.add(spec.getString("id"))
            } else remainingPlans.put(spec)
        }
        val remainingEvents = JSONArray()
        val currentEvents = events()
        for (i in 0 until currentEvents.length()) {
            val event = currentEvents.getJSONObject(i)
            if (event.optString("space") != space) remainingEvents.put(event)
        }
        val edit = prefs().edit()
            .putString("plans", remainingPlans.toString())
            .putString("events", remainingEvents.toString())
        for (taskId in removedTaskIds) edit.remove("id:$taskId").remove("fired:$taskId")
        edit.commit()
    }

    private fun localDate(parts: JSONArray, minutes: Int): Calendar = Calendar.getInstance().apply {
        clear()
        set(parts.getInt(0), parts.getInt(1) - 1, parts.getInt(2), minutes / 60, minutes % 60)
    }
    private fun reminderTime(spec: JSONObject): Long? {
        val date = spec.optJSONArray("date") ?: return null
        val rule = spec.optString("reminder", "none")
        if (rule == "none") return null
        val minutes = if (spec.isNull("minutes")) spec.optInt("morningMinutes", 540) else spec.getInt("minutes")
        val calendar = localDate(date, minutes)
        calendar.add(Calendar.DATE, when (rule) { "oneDay" -> -1; "twoDays" -> -2; "oneWeek" -> -7; else -> 0 })
        calendar.add(Calendar.MINUTE, when (rule) { "tenMinutes" -> -10; "thirtyMinutes" -> -30; "oneHour" -> -60; else -> 0 })
        return calendar.timeInMillis
    }
    private fun schedule(spec: JSONObject, action: String, at: Long) {
        val operation = pending(spec, action)
        if (Build.VERSION.SDK_INT < 31 || alarms().canScheduleExactAlarms()) {
            alarms().setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        } else alarms().setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
    }
    private fun reconcile(spec: JSONObject) {
        val now = System.currentTimeMillis()
        alarms().cancel(pending(spec, "remind"))
        alarms().cancel(pending(spec, "activate"))
        if (!allowed()) return
        val available = spec.optJSONArray("availableDate")?.let { localDate(it, 0).timeInMillis } ?: 0L
        if (spec.optBoolean("pinned")) {
            if (available <= now) show(spec, false)
            else { manager().cancel(notificationId(spec.getString("id"))); schedule(spec, "activate", available) }
        } else {
            val active = if (Build.VERSION.SDK_INT >= 23) manager().activeNotifications.firstOrNull { it.id == notificationId(spec.getString("id")) } else null
            if (active != null && active.notification.flags and Notification.FLAG_ONGOING_EVENT != 0) manager().cancel(active.id)
        }
        reminderTime(spec)?.let { at ->
            if (at > now && prefs().getLong("fired:${spec.getString("id")}", -1) != at) schedule(spec, "remind", at)
        }
    }
    fun restore() {
        val list = plans()
        for (i in 0 until list.length()) reconcile(list.getJSONObject(i))
        channel.invokeMethod("events", null)
    }
    private fun language(spec: JSONObject): String {
        val tag = spec.optString(
            "language",
            context.resources.configuration.locales[0].toLanguageTag(),
        )
        return when {
            tag.equals("pt-BR", ignoreCase = true) -> "pt-BR"
            tag.startsWith("de", ignoreCase = true) -> "de"
            tag.startsWith("es", ignoreCase = true) -> "es"
            tag.startsWith("fr", ignoreCase = true) -> "fr"
            tag.startsWith("ja", ignoreCase = true) -> "ja"
            else -> "en"
        }
    }
    private fun text(spec: JSONObject, en: String, de: String, es: String, pt: String, fr: String, ja: String) = when (language(spec)) {
        "de" -> de
        "es" -> es
        "pt-BR" -> pt
        "fr" -> fr
        "ja" -> ja
        else -> en
    }
    private fun body(spec: JSONObject, alert: Boolean): String {
        val description = spec.optString("description").trim()
        if (description.isNotEmpty()) return description
        val date = spec.optJSONArray("date")
        val today = Calendar.getInstance()
        val sameDay = date != null && date.getInt(0) == today.get(Calendar.YEAR) && date.getInt(1) == today.get(Calendar.MONTH)+1 && date.getInt(2) == today.get(Calendar.DATE)
        val day = if (sameDay) {
            text(spec, "Today", "Heute", "Hoy", "Hoje", "Aujourd’hui", "今日")
        } else date?.let {
            DateFormat.getDateInstance(DateFormat.SHORT, Locale.forLanguageTag(language(spec))).format(localDate(it, 0).time)
        } ?: ""
        if (spec.isNull("minutes")) return if (sameDay) {
            text(spec, "Due today", "Heute fällig", "Vence hoy", "Vence hoje", "Échéance aujourd’hui", "今日が期限")
        } else day
        val minutes = spec.getInt("minutes")
        val time = "%02d:%02d".format(minutes / 60, minutes % 60)
        val until = date?.let { (localDate(it, minutes).timeInMillis - System.currentTimeMillis() + 59999) / 60000 }
        val label = if (alert && until != null && until in 1..60) {
            text(spec, "In $until minutes", "In $until Minuten", "En $until minutos", "Em $until minutos", "Dans $until minutes", "${until}分後")
        } else day
        return listOf(label, time).filter { it.isNotEmpty() }.joinToString(" · ")
    }
    private fun show(spec: JSONObject, alert: Boolean) {
        if (!allowed()) return
        val pinned = spec.optBoolean("pinned")
        val open = Intent(context, MainActivity::class.java).setAction("open")
            .setData(Uri.parse("sometime://task/${Uri.encode(spec.getString("id"))}"))
            .putExtra("task", spec.getString("id")).putExtra("space", spec.getString("space"))
        val content = PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, if (alert) REMINDERS else PINS) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_notification).setContentTitle(spec.getString("title"))
            .setContentText(body(spec, alert)).setContentIntent(content).setOngoing(pinned)
            .setAutoCancel(!pinned).setOnlyAlertOnce(!alert).setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(null, text(spec, "Complete", "Erledigen", "Completar", "Concluir", "Terminer", "完了"), pending(spec, "complete")).build())
        if (pinned) builder.setDeleteIntent(pending(spec, "unpin"))
            .addAction(Notification.Action.Builder(null, text(spec, "Unpin", "Lösen", "Desfijar", "Desafixar", "Désépingler", "ピン留めを解除"), pending(spec, "unpin")).build())
        if (Build.VERSION.SDK_INT < 26 && alert) builder.setDefaults(Notification.DEFAULT_ALL)
        manager().notify(notificationId(spec.getString("id")), builder.build())
    }
    fun receive(intent: Intent, result: BroadcastReceiver.PendingResult? = null) {
        val action = intent.action ?: return
        if (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED, AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) {
            restore(); result?.finish(); return
        }
        val task = intent.getStringExtra("task") ?: run { result?.finish(); return }
        val list = plans()
        val spec = (0 until list.length()).map { list.getJSONObject(it) }.firstOrNull { it.getString("id") == task }
        if (action == "remind" || action == "activate") {
            if (spec != null) {
                val at = reminderTime(spec)
                // Drop stale alarms after a clock change or a long device shutdown.
                if (action == "activate") { if (spec.optBoolean("pinned")) show(spec, false) }
                else if (at != null && System.currentTimeMillis() - at in 0..900000L) {
                    prefs().edit().putLong("fired:$task", at).commit()
                    show(spec, true)
                }
            }
            result?.finish(); return
        }
        if (action !in listOf("open", "complete", "unpin")) { result?.finish(); return }
        if (spec != null && action != "open") {
            cancel(spec)
            val next = JSONArray()
            for (i in 0 until list.length()) {
                val entry = list.getJSONObject(i)
                if (entry.getString("id") == task) {
                    if (action == "unpin") next.put(entry.put("pinned", false))
                } else next.put(entry)
            }
            prefs().edit().putString("plans", next.toString()).commit()
        }
        val queue = events().put(JSONObject().put("id", UUID.randomUUID().toString()).put("task", task)
            .put("space", intent.getStringExtra("space")).put("action", action))
        prefs().edit().putString("events", queue.toString()).commit()
        if (result != null) {
            waiting.add(result)
            Handler(Looper.getMainLooper()).postDelayed({ if (waiting.remove(result)) result.finish() }, 8500)
        }
        channel.invokeMethod("events", null)
    }
}

class TaskNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        try { TaskNotifications.receive(intent, pending) }
        catch (_: Exception) { pending.finish() }
    }
}

