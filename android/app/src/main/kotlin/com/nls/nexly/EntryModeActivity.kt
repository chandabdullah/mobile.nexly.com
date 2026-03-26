package com.nls.nexly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

abstract class EntryModeActivity : FlutterActivity() {
  private val channelName = "nexly/entry_mode"

  protected abstract val entryMode: String

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getLaunchMode" -> result.success(entryMode)
          else -> result.notImplemented()
        }
      }
  }
}
