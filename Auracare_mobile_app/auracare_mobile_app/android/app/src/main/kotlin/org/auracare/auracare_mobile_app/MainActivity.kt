package org.auracare.auracare_mobile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("auracare_setup", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.auracare/setup")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "completed" -> result.success(preferences.getBoolean("completed", false))
                    "complete" -> result.success(preferences.edit().putBoolean("completed", true).commit())
                    else -> result.notImplemented()
                }
            }
    }
}
