package com.mytogetherorg.mytogether

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL

class OrderTrackerService : Service() {

    companion object {
        const val CHANNEL_ID = "order_tracker_channel"
        const val NOTIFICATION_ID = 1001

        const val EXTRA_SHOP_NAME = "shop_name"
        const val EXTRA_SHOP_LOGO = "shop_logo"

        fun startService(context: Context, shopName: String, shopLogoUrl: String) {
            val intent = Intent(context, OrderTrackerService::class.java).apply {
                putExtra(EXTRA_SHOP_NAME, shopName)
                putExtra(EXTRA_SHOP_LOGO, shopLogoUrl)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, OrderTrackerService::class.java)
            context.stopService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val shopName = intent?.getStringExtra(EXTRA_SHOP_NAME) ?: "Shop"
        val shopLogoUrl = intent?.getStringExtra(EXTRA_SHOP_LOGO) ?: ""

        val placeholder = buildNotification(shopName, null)
        startForegroundWithNotification(placeholder)

        if (shopLogoUrl.isNotEmpty()) {
            Thread {
                val bitmap = fetchBitmap(shopLogoUrl)
                val updated = buildNotification(shopName, bitmap)
                val manager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, updated)
            }.start()
        }

        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(shopName: String, logoBitmap: Bitmap?): Notification {
        val remoteViews = RemoteViews(packageName, R.layout.notification_order_tracker)
        remoteViews.setTextViewText(R.id.shop_name, shopName)

        if (logoBitmap != null) {
            remoteViews.setImageViewBitmap(R.id.shop_logo, logoBitmap)
        } else {
            remoteViews.setImageViewResource(R.id.shop_logo, R.drawable.ic_store)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun fetchBitmap(urlString: String): Bitmap? {
        return try {
            val connection = URL(urlString).openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.doInput = true
            connection.connect()
            connection.inputStream.use { stream ->
                BitmapFactory.decodeStream(stream)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Order Tracking",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows your active order"
                setSound(null, null)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
