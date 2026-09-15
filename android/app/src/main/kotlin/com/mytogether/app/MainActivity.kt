package com.mytogetherorg.mytogether

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "secure_screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mytogether/order_tracker").setMethodCallHandler { call, result ->
            // OrderTrackerService disabled as requested by user
            result.success(true)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mytogether/active_call").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val callerName = call.argument<String>("callerName") ?: "Ongoing Call"
                    val baseTime   = call.argument<Long>("baseTime") ?: 0L
                    val intent = android.content.Intent(this, ActiveCallService::class.java).apply {
                        putExtra("callerName", callerName)
                        putExtra("baseTime",   baseTime)
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "update" -> {
                    // Refresh notification with updated caller name (e.g. after call is answered)
                    val callerName = call.argument<String>("callerName") ?: "Ongoing Call"
                    val baseTime   = call.argument<Long>("baseTime") ?: 0L
                    val intent = android.content.Intent(this, ActiveCallService::class.java).apply {
                        putExtra("callerName", callerName)
                        putExtra("baseTime",   baseTime)
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stop" -> {
                    val intent = android.content.Intent(this, ActiveCallService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
