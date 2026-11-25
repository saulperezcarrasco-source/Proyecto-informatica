package com.example.ruta_rd

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var gnss: GnssStreamHandler? = null
    private var channel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        gnss = GnssStreamHandler(this)
        channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "ruta_rd/gnss")
        channel?.setStreamHandler(gnss)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        gnss?.stop()
        channel?.setStreamHandler(null)
        channel = null
        gnss = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
