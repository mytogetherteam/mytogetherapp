package com.mytogetherorg.mytogether

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

class OrderTrackerService : Service() {

    companion object {
        const val CHANNEL_ID = "order_tracker_channel"
        const val NOTIFICATION_ID = 1001

        const val EXTRA_SHOP_NAME = "shop_name"
        const val EXTRA_STATUS_TEXT = "status_text"
        const val EXTRA_STEP = "step"

        fun startService(context: Context, shopName: String, statusText: String, step: Int) {
            val intent = Intent(context, OrderTrackerService::class.java).apply {
                putExtra(EXTRA_SHOP_NAME, shopName)
                putExtra(EXTRA_STATUS_TEXT, statusText)
                putExtra(EXTRA_STEP, step)
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
        val statusText = intent?.getStringExtra(EXTRA_STATUS_TEXT) ?: "Status"
        val step = intent?.getIntExtra(EXTRA_STEP, 0) ?: 0

        val notification = buildNotification(shopName, statusText, step)
        startForeground(NOTIFICATION_ID, notification)

        return START_NOT_STICKY
    }

    private fun buildNotification(shopName: String, statusText: String, step: Int): Notification {
        val remoteViews = RemoteViews(packageName, R.layout.notification_order_tracker)
        
        remoteViews.setTextViewText(R.id.shop_name, shopName)
        remoteViews.setTextViewText(R.id.status_text, statusText)

        // Set Step 1 (Store)
        remoteViews.setInt(R.id.icon_step_1, "setBackgroundResource", R.drawable.bg_oval_active)
        remoteViews.setInt(R.id.icon_step_1, "setColorFilter", android.graphics.Color.WHITE)

        // Set Step 2 (Receipt)
        if (step >= 2) {
            remoteViews.setInt(R.id.line_1, "setBackgroundColor", android.graphics.Color.parseColor("#ED3973"))
            remoteViews.setInt(R.id.icon_step_2, "setBackgroundResource", R.drawable.bg_oval_active)
            remoteViews.setInt(R.id.icon_step_2, "setColorFilter", android.graphics.Color.WHITE)
        } else {
            remoteViews.setInt(R.id.line_1, "setBackgroundColor", android.graphics.Color.parseColor("#EEEEEE"))
            remoteViews.setInt(R.id.icon_step_2, "setBackgroundResource", R.drawable.bg_oval_inactive)
            remoteViews.setInt(R.id.icon_step_2, "setColorFilter", android.graphics.Color.parseColor("#AAAAAA"))
        }

        // Set Step 3 (Bike)
        if (step >= 3) {
            remoteViews.setInt(R.id.line_2, "setBackgroundColor", android.graphics.Color.parseColor("#ED3973"))
            remoteViews.setInt(R.id.icon_step_3, "setBackgroundResource", R.drawable.bg_oval_active)
            remoteViews.setInt(R.id.icon_step_3, "setColorFilter", android.graphics.Color.WHITE)
        } else {
            remoteViews.setInt(R.id.line_2, "setBackgroundColor", android.graphics.Color.parseColor("#EEEEEE"))
            remoteViews.setInt(R.id.icon_step_3, "setBackgroundResource", R.drawable.bg_oval_inactive)
            remoteViews.setInt(R.id.icon_step_3, "setColorFilter", android.graphics.Color.parseColor("#AAAAAA"))
        }

        // Set Step 4 (Home)
        if (step >= 4) {
            remoteViews.setInt(R.id.line_3, "setBackgroundColor", android.graphics.Color.parseColor("#ED3973"))
            remoteViews.setInt(R.id.icon_step_4, "setBackgroundResource", R.drawable.bg_oval_active)
            remoteViews.setInt(R.id.icon_step_4, "setColorFilter", android.graphics.Color.WHITE)
        } else {
            remoteViews.setInt(R.id.line_3, "setBackgroundColor", android.graphics.Color.parseColor("#EEEEEE"))
            remoteViews.setInt(R.id.icon_step_4, "setBackgroundResource", R.drawable.bg_oval_inactive)
            remoteViews.setInt(R.id.icon_step_4, "setColorFilter", android.graphics.Color.parseColor("#AAAAAA"))
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon) // Fallback icon
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Order Tracking",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows live order tracking progress"
                setSound(null, null) // No sound for ongoing updates
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
