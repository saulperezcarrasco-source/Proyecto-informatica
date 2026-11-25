package com.example.ruta_rd

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel

/** Foreground-only satellite fixes, independent of network/fused providers. */
class GnssStreamHandler(private val activity: Activity) : EventChannel.StreamHandler {
    private val manager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var listener: LocationListener? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
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
                events.success(mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to if (location.hasAccuracy()) location.accuracy.toDouble() else Double.POSITIVE_INFINITY,
                    "timestamp" to location.time,
                    "speed" to if (location.hasSpeed()) location.speed.toDouble() else 0.0,
                    "heading" to if (location.hasBearing()) location.bearing.toDouble() else -1.0
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
        listener?.let { runCatching { manager.removeUpdates(it) } }
        listener = null
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
