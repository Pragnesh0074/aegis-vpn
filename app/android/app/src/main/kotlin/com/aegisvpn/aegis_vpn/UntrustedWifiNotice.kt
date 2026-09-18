package com.aegisvpn.aegis_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Tells the user the tunnel came up because the Wi-Fi they joined is not trusted,
 * and offers to trust it.
 *
 * A notification rather than a dialog because this fires exactly when the app is
 * NOT on screen — walking into a café with Aegis in the background is the case
 * auto-connect exists for, and Android will not let a background app put a dialog
 * in front of anyone.
 *
 * The action launches the app carrying the SSID rather than writing the trusted
 * list itself. That list lives in Flutter's secure storage, which native cannot
 * reach, and the indirection is worth more than it costs: the decision lands in
 * the one place that owns it, and it still works from a cold start.
 */
object UntrustedWifiNotice {

    const val EXTRA_TRUST_SSID = "com.aegisvpn.aegis_vpn.TRUST_SSID"

    private const val CHANNEL_ID = "aegis.wifi"
    private const val NOTIFICATION_ID = 0x4E31

    fun show(context: Context, ssid: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        // Low importance: this is a "here is what happened, change it if you
        // like" notice, not an alert. It should not make a sound for someone who
        // simply walked into a coffee shop.
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Wi-Fi networks",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Tells you when Aegis connects on a network you have not trusted."
            },
        )

        val trust = PendingIntent.getActivity(
            context,
            ssid.hashCode(),
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .putExtra(EXTRA_TRUST_SSID, ssid)
                // Brings the existing task forward rather than stacking a second
                // copy of the app behind the one already running.
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_tile_shield)
            .setContentTitle("Connected on $ssid")
            .setContentText("Not a trusted network, so Aegis turned on. Trust it to stop that.")
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "Aegis connected because $ssid is not on your trusted list. " +
                        "Trust it and Aegis will leave it alone from now on.",
                ),
            )
            .addAction(
                Notification.Action.Builder(null, "Trust this network", trust).build(),
            )
            .setAutoCancel(true)
            .build()

        // Posting is best-effort: on Android 13+ the user may not have granted
        // notification permission, and a protection feature must not fall over
        // because it could not tell anyone about itself.
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // No notification permission. The in-app banner still covers the
            // case where the app is open.
        }
    }

    fun dismiss(context: Context) {
        context.getSystemService(NotificationManager::class.java)
            ?.cancel(NOTIFICATION_ID)
    }
}
