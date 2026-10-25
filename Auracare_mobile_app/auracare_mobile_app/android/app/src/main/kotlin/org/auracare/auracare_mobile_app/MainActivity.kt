package org.auracare.auracare_mobile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.AtomicFile
import android.content.Intent
import android.net.Uri
import java.io.File

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
        val appointments = AtomicFile(File(noBackupFilesDir, "appointments.json"))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.auracare/appointments")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> result.success(if (appointments.baseFile.exists() || File(appointments.baseFile.path + ".bak").exists()) appointments.openRead().bufferedReader(Charsets.UTF_8).use { it.readText() } else null)
                        "write" -> {
                            val json = call.arguments as? String ?: throw IllegalArgumentException("Missing appointment data")
                            require(json.length <= 2_000_000)
                            val output = appointments.startWrite()
                            try {
                                output.write(json.toByteArray(Charsets.UTF_8))
                                appointments.finishWrite(output)
                            } catch (error: Exception) {
                                appointments.failWrite(output)
                                throw error
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("APPOINTMENT_STORAGE", "Private appointment storage unavailable", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.auracare/links")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") { result.notImplemented() } else {
                    try {
                        val uri = Uri.parse(call.arguments as String)
                        require(uri.scheme == "https" && uri.host in setOf("www.nhs.uk", "www.who.int", "www.cdc.gov", "health.nih.gov"))
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(true)
                    } catch (_: Exception) { result.success(false) }
                }
            }
    }
}
