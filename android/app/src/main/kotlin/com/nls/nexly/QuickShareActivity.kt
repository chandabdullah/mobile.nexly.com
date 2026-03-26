package com.nls.nexly

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.RenderMode

class QuickShareActivity : EntryModeActivity() {
  override val entryMode: String = "quick"

  override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

  override fun getRenderMode(): RenderMode = RenderMode.texture

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
    window.decorView.setBackgroundColor(Color.TRANSPARENT)
    window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
    window.setDimAmount(0f)
    overridePendingTransition(0, 0)
  }
}
