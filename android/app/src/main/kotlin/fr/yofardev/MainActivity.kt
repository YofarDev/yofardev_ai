package fr.yofardev

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var thermalListener: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // The device's thermal state for the quality tiers (moonshot M11
        // ruling 12): local OS state only, nothing leaves the device.
        MethodChannel(messenger, "yofardev/thermal_state").setMethodCallHandler { call, result ->
            if (call.method == "current") {
                result.success(currentThermalLevel())
            } else {
                result.notImplemented()
            }
        }
        EventChannel(messenger, "yofardev/thermal").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    events.success(currentThermalLevel())
                    startThermalListener(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopThermalListener()
                }
            },
        )
    }

    override fun onDestroy() {
        stopThermalListener()
        super.onDestroy()
    }

    private fun powerManager(): PowerManager =
        getSystemService(Context.POWER_SERVICE) as PowerManager

    /** The thermal status as the Dart `ThermalLevel` name (API < 29: nominal). */
    private fun currentThermalLevel(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return "nominal"
        }
        return thermalLevelName(powerManager().currentThermalStatus)
    }

    private fun thermalLevelName(status: Int): String =
        when (status) {
            PowerManager.THERMAL_STATUS_NONE -> "nominal"
            PowerManager.THERMAL_STATUS_LIGHT -> "light"
            PowerManager.THERMAL_STATUS_MODERATE -> "moderate"
            PowerManager.THERMAL_STATUS_SEVERE -> "severe"
            PowerManager.THERMAL_STATUS_CRITICAL,
            PowerManager.THERMAL_STATUS_EMERGENCY,
            PowerManager.THERMAL_STATUS_SHUTDOWN,
            -> "critical"
            else -> "nominal"
        }

    private fun startThermalListener(events: EventChannel.EventSink) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        stopThermalListener()
        val main = Handler(Looper.getMainLooper())
        val listener =
            PowerManager.OnThermalStatusChangedListener { status ->
                main.post { events.success(thermalLevelName(status)) }
            }
        powerManager().addThermalStatusListener(listener)
        thermalListener = listener
    }

    private fun stopThermalListener() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        val listener = thermalListener as? PowerManager.OnThermalStatusChangedListener ?: return
        powerManager().removeThermalStatusListener(listener)
        thermalListener = null
    }
}
