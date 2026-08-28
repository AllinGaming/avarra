package dev.avarra.avarra_game

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.TrafficStats
import android.os.BatteryManager
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
            val battery = currentBatterySnapshot()
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            @Suppress("DEPRECATION")
            val appBuildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                packageInfo.versionCode.toLong()
            }
            result.success(
                mapOf(
                    "memoryBytes" to memoryInfo.totalPss.toLong() * 1024L,
                    "thermalStatus" to currentThermalStatus(),
                    "networkTxBytes" to TrafficStats.getUidTxBytes(uid),
                    "networkRxBytes" to TrafficStats.getUidRxBytes(uid),
                    "batteryLevelPercent" to battery.first,
                    "batteryCharging" to battery.second,
                    "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
                    "operatingSystemVersion" to
                        "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                    "appVersion" to packageInfo.versionName,
                    "appBuildNumber" to appBuildNumber.toString(),
                ),
            )
        }
    }

    private fun currentBatterySnapshot(): Pair<Double?, Boolean?> {
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return Pair(null, null)
        val level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val percent = if (level >= 0 && scale > 0) level * 100.0 / scale else null
        val status = battery.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val charging = when (status) {
            BatteryManager.BATTERY_STATUS_CHARGING,
            BatteryManager.BATTERY_STATUS_FULL -> true
            BatteryManager.BATTERY_STATUS_DISCHARGING,
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> false
            else -> null
        }
        return Pair(percent, charging)
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
