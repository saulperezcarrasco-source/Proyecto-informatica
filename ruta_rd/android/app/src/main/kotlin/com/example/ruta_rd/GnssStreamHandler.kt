package com.example.ruta_rd

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.GnssStatus
import android.os.Handler
import android.os.Bundle
import android.os.Looper
import android.os.Build
import android.os.SystemClock
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel

/** Foreground-only satellite fixes, independent of network/fused providers. */
class GnssStreamHandler(private val activity: Activity) : EventChannel.StreamHandler {
    private val manager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var listener: LocationListener? = null
    private var satelliteCallback: GnssStatus.Callback? = null
    private var visible: Int? = null
    private var used: Int? = null
    private var statusAt: Long? = null
    private var fixAt: Long? = null
    private var lastAccuracy: Double? = null
    private var lastSpeed: Double? = null
    private var lastSpeedAccuracy: Double? = null
    private var fixes = 0

    fun diagnostics(): Map<String, Any?> {
        val now = SystemClock.elapsedRealtime()
        return mapOf(
            "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "android" to Build.VERSION.RELEASE,
            "version" to activity.packageManager.getPackageInfo(activity.packageName, 0).versionName,
            "precisePermission" to (activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED),
            "gpsEnabled" to runCatching { manager.isProviderEnabled(LocationManager.GPS_PROVIDER) }.getOrDefault(false),
            "tracking" to (listener != null),
            "visibleSatellites" to visible,
            "usedSatellites" to used,
            "satelliteStatusAgeMillis" to statusAt?.let { now - it },
            "fixAgeMillis" to fixAt?.let { now - it },
            "accuracyMeters" to lastAccuracy,
            "speedMetersPerSecond" to lastSpeed,
            "speedAccuracy" to lastSpeedAccuracy,
            "fixesReceived" to fixes
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        visible = null
        used = null
        statusAt = null
        fixAt = null
        lastAccuracy = null
        lastSpeed = null
        lastSpeedAccuracy = null
        fixes = 0
        if (activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            events.error("PRECISE_PERMISSION_REQUIRED", "Precise location permission is required", null)
            return
        }
        if (!manager.allProviders.contains(LocationManager.GPS_PROVIDER)) {
            events.error("GPS_UNAVAILABLE", "No satellite location provider", null)
            return
        }
        if (!manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            events.error("SERVICE_DISABLED", "Satellite location is disabled", null)
            return
        }
        val subscription = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                fixAt = location.elapsedRealtimeNanos / 1000000L
                lastAccuracy = if (location.hasAccuracy()) location.accuracy.toDouble() else null
                lastSpeed = if (location.hasSpeed()) location.speed.toDouble() else null
                lastSpeedAccuracy = if (Build.VERSION.SDK_INT >= 26 && location.hasSpeed() && location.hasSpeedAccuracy()) location.speedAccuracyMetersPerSecond.toDouble() else null
                fixes++
                events.success(mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to if (location.hasAccuracy()) location.accuracy.toDouble() else Double.POSITIVE_INFINITY,
                    "timestamp" to location.time,
                    "ageMillis" to ((SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1000000L).coerceAtLeast(0L),
                    "speed" to if (location.hasSpeed()) location.speed.toDouble() else 0.0,
                    "heading" to if (location.hasBearing()) location.bearing.toDouble() else -1.0,
                    "headingAccuracy" to if (Build.VERSION.SDK_INT >= 26 && location.hasBearingAccuracy()) location.bearingAccuracyDegrees.toDouble() else -1.0,
                    "speedAccuracy" to (lastSpeedAccuracy ?: -1.0)
                ))
            }
            override fun onProviderDisabled(provider: String) {
                if (provider == LocationManager.GPS_PROVIDER) {
                    events.error("SERVICE_DISABLED", "Satellite location was disabled", null)
                }
            }
            override fun onProviderEnabled(provider: String) {}
            @Deprecated("Required for older Android versions")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        listener = subscription
        try {
            // Zero minimum distance also delivers improving stationary fixes.
            manager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, subscription, Looper.getMainLooper())
            // Satellite status is diagnostic only: some receivers omit it even
            // when they deliver positions. It never gates navigation updates.
            val callback = object : GnssStatus.Callback() {
                override fun onSatelliteStatusChanged(status: GnssStatus) {
                    visible = status.satelliteCount
                    used = (0 until status.satelliteCount).count { status.usedInFix(it) }
                    statusAt = SystemClock.elapsedRealtime()
                }
            }
            if (runCatching { manager.registerGnssStatusCallback(callback, Handler(Looper.getMainLooper())) }.getOrDefault(false)) {
                satelliteCallback = callback
            }
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } catch (error: SecurityException) {
            stop()
            events.error("PRECISE_PERMISSION_REQUIRED", "Location permission was revoked", null)
        } catch (error: Exception) {
            stop()
            events.error("GPS_UNAVAILABLE", "Could not start satellite location", null)
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        satelliteCallback?.let { runCatching { manager.unregisterGnssStatusCallback(it) } }
        satelliteCallback = null
        listener?.let { runCatching { manager.removeUpdates(it) } }
        listener = null
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
