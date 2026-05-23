package com.glance.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class GlanceWidgetProvider : AppWidgetProvider() {

    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        const val ACTION_UPDATE_PHOTO = "com.glance.app.ACTION_UPDATE_PHOTO"
        private const val SHARED_PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PHOTO_URL = "flutter.glance_photo_url"
        private const val KEY_SENDER_NAME = "flutter.glance_sender_name"
        private const val KEY_TIMESTAMP = "flutter.glance_timestamp"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE_PHOTO || intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, GlanceWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.glance_widget_layout)

        // Read data from Shared Preferences (written by Flutter's HomeWidget package)
        val prefs = context.getSharedPreferences(SHARED_PREFS_NAME, Context.MODE_PRIVATE)
        val photoUrl = prefs.getString(KEY_PHOTO_URL, "") ?: ""
        val senderName = prefs.getString(KEY_SENDER_NAME, "Friend") ?: "Friend"
        val timestamp = prefs.getString(KEY_TIMESTAMP, "Just now") ?: "Just now"

        // Set static text views
        views.setTextViewText(R.id.widget_sender_text, senderName)
        views.setTextViewText(R.id.widget_time_text, timestamp)

        // Set click intent to open main application on the container
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

        // Set click intent for the retry layout
        val retryIntent = Intent(context, GlanceWidgetProvider::class.java).apply {
            action = ACTION_UPDATE_PHOTO
        }
        val retryPendingIntent = PendingIntent.getBroadcast(
            context, 1, retryIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_error_layout, retryPendingIntent)

        // Deduplication Check
        val photoId = prefs.getString("flutter.glance_photo_id", "") ?: ""
        val lastSeenPhotoId = prefs.getString("last_seen_photo_id", "") ?: ""

        if (photoUrl.isNotEmpty()) {
            // Load photo asynchronously using background thread executor
            executor.execute {
                var bypassDownload = false
                if (photoId.isNotEmpty() && photoId == lastSeenPhotoId) {
                    val cacheFile = java.io.File(context.cacheDir, "glance_widget_cache.jpg")
                    if (cacheFile.exists()) {
                        bypassDownload = true
                    }
                }
                
                val bitmapResult = if (bypassDownload) {
                    val cachedBitmap = android.graphics.BitmapFactory.decodeFile(java.io.File(context.cacheDir, "glance_widget_cache.jpg").absolutePath)
                    BitmapResult(cachedBitmap, cachedBitmap == null)
                } else {
                    val result = downloadBitmapWithCache(context, photoUrl)
                    if (result.bitmap != null && photoId.isNotEmpty()) {
                        prefs.edit().putString("last_seen_photo_id", photoId).apply()
                    }
                    result
                }
                
                handler.post {
                    if (bitmapResult.bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image_view, bitmapResult.bitmap)
                        views.setViewVisibility(R.id.widget_error_layout, android.view.View.GONE)
                    } else {
                        views.setImageViewResource(R.id.widget_image_view, R.drawable.widget_placeholder)
                        views.setViewVisibility(R.id.widget_error_layout, android.view.View.VISIBLE)
                    }
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            }
        } else {
            views.setImageViewResource(R.id.widget_image_view, R.drawable.widget_placeholder)
            views.setViewVisibility(R.id.widget_error_layout, android.view.View.GONE)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    data class BitmapResult(val bitmap: Bitmap?, val isError: Boolean)

    private fun downloadBitmapWithCache(context: Context, urlStr: String): BitmapResult {
        val cacheFile = java.io.File(context.cacheDir, "glance_widget_cache.jpg")
        var connection: HttpURLConnection? = null
        var inputStream: InputStream? = null
        
        try {
            val url = URL(urlStr)
            connection = url.openConnection() as HttpURLConnection
            connection.doInput = true
            connection.connectTimeout = 10000 // 10 seconds timeout
            connection.readTimeout = 10000 // 10 seconds timeout
            connection.connect()
            
            if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                inputStream = connection.inputStream
                val bitmap = BitmapFactory.decodeStream(inputStream)
                
                // Save to cache
                if (bitmap != null) {
                    java.io.FileOutputStream(cacheFile).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, out)
                    }
                    return BitmapResult(bitmap, false)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("GlanceWidgetProvider", "Error downloading or caching widget image", e)
            e.printStackTrace()
        } finally {
            inputStream?.close()
            connection?.disconnect()
        }
        
        // If download failed, try to load from cache
        if (cacheFile.exists()) {
            try {
                val cachedBitmap = BitmapFactory.decodeFile(cacheFile.absolutePath)
                if (cachedBitmap != null) {
                    return BitmapResult(cachedBitmap, false)
                }
            } catch (e: Exception) {
                android.util.Log.e("GlanceWidgetProvider", "Error reading widget image from cache", e)
                e.printStackTrace()
            }
        }
        
        return BitmapResult(null, true)
    }
}
