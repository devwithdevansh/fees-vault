package com.feesvault.fees_vault

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.feesvault.security"
    private var methodChannel: MethodChannel? = null
    private var screenCaptureCallback: Any? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prohibit screenshots and screen recordings throughout the entire app.
        // Also obscures app preview thumbnail in Android Recents / App Switcher.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        // On Android 14+ (API 34+), register ScreenCaptureCallback to detect screenshot attempts
        // and notify Flutter to immediately revert to app unlocking phase.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val callback = android.app.Activity.ScreenCaptureCallback {
                runOnUiThread {
                    methodChannel?.invokeMethod("onScreenshotDetected", null)
                }
            }
            screenCaptureCallback = callback
            registerScreenCaptureCallback(mainExecutor, callback)
        }
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            (screenCaptureCallback as? android.app.Activity.ScreenCaptureCallback)?.let {
                try {
                    unregisterScreenCaptureCallback(it)
                } catch (_: Exception) {}
            }
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openSecuritySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("SETTINGS_ERROR", ex.localizedMessage, null)
                        }
                    }
                }
                "isDeviceLockEnrolled" -> {
                    val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    val isSecure = keyguardManager?.isDeviceSecure ?: false
                    result.success(isSecure)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
