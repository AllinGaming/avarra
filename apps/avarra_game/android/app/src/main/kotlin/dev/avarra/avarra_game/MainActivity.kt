package dev.avarra.avarra_game

import android.app.ActivityManager
import android.content.Context
import android.net.TrafficStats
import android.os.Build
import android.os.PowerManager
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.avarra/host_metrics",
        ).setMethodCallHandler { call, result ->
            if (call.method != "sample") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = activityManager.getProcessMemoryInfo(intArrayOf(Process.myPid())).first()
            val uid = applicationInfo.uid
            result.success(
                mapOf(
                    "memoryBytes" to memoryInfo.totalPss.toLong() * 1024L,
                    "thermalStatus" to currentThermalStatus(),
                    "networkTxBytes" to TrafficStats.getUidTxBytes(uid),
                    "networkRxBytes" to TrafficStats.getUidRxBytes(uid),
                ),
            )
        }
    }

    private fun currentThermalStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return "unsupported"
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return when (powerManager.currentThermalStatus) {
            PowerManager.THERMAL_STATUS_NONE -> "none"
            PowerManager.THERMAL_STATUS_LIGHT -> "light"
            PowerManager.THERMAL_STATUS_MODERATE -> "moderate"
            PowerManager.THERMAL_STATUS_SEVERE -> "severe"
            PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
            PowerManager.THERMAL_STATUS_EMERGENCY -> "emergency"
            PowerManager.THERMAL_STATUS_SHUTDOWN -> "shutdown"
            else -> "unknown"
        }
    }
}
