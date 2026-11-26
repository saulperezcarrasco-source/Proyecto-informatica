package com.example.ruta_rd

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var gnss: GnssStreamHandler? = null
    private var channel: EventChannel? = null
    private var diagnosticsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        gnss = GnssStreamHandler(this)
        channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "ruta_rd/gnss")
        channel?.setStreamHandler(gnss)
        diagnosticsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ruta_rd/gps_diagnostics")
        diagnosticsChannel?.setMethodCallHandler { call, result ->
            if (call.method == "snapshot") result.success(gnss?.diagnostics())
            else result.notImplemented()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        gnss?.stop()
        channel?.setStreamHandler(null)
        channel = null
        diagnosticsChannel?.setMethodCallHandler(null)
        diagnosticsChannel = null
        gnss = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
