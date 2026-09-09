package eu.eikrose.sometime

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine = (application as SometimeApplication).engine
    override fun shouldDestroyEngineWithHost() = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        TaskNotifications.activity = this
        TaskNotifications.receive(intent)
        SometimeWidgets.receive(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        TaskNotifications.receive(intent)
        SometimeWidgets.receive(intent)
    }
    override fun onResume() { super.onResume(); TaskNotifications.activity = this }
    override fun onDestroy() {
        if (TaskNotifications.activity === this) TaskNotifications.activity = null
        super.onDestroy()
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 701) TaskNotifications.permissionReply()
    }
}
