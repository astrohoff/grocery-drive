package com.astrohoff.grocerydrive.grocery_drive

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "grocery_drive/browser",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val url = call.argument<String>("url")
            if (url.isNullOrEmpty()) {
                result.error("bad_url", "Missing url", null)
                return@setMethodCallHandler
            }
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            }
        }
    }
}
