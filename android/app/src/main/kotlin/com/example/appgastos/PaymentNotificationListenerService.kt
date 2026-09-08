package com.example.appgastos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray

/**
 * Escucha las notificaciones del sistema (requiere el permiso especial
 * "Acceso a notificaciones", activado a mano por el usuario). Cuando una
 * notificación de una app configurada en Ajustes contiene alguna de las
 * palabras clave configuradas, dispara una notificación propia de "posible
 * pago detectado" que abre la app en la pantalla de verificación.
 *
 * No depende de que la app/engine de Flutter esté corriendo: toda la
 * lógica de match vive acá, en Kotlin puro, leyendo la config que Flutter
 * ya dejó guardada en el mismo archivo de SharedPreferences que usa
 * `shared_preferences` (así no hace falta duplicar almacenamiento).
 */
class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val CONFIG_KEY = "flutter.appgastos.paymentwatch.v1"
        private const val CHANNEL_ID = "payment_detected_native_channel"
        private var nextNotificationId = 5000
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        try {
            handle(sbn)
        } catch (_: Exception) {
            // Una notificación con un formato raro no debe tumbar el listener.
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return

        val watchList = loadWatchList() ?: return
        if (watchList.length() == 0) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val combined = listOf(title, text, bigText).filter { it.isNotBlank() }.joinToString("\n")
        if (combined.isBlank()) return

        for (i in 0 until watchList.length()) {
            val entry = watchList.optJSONObject(i) ?: continue
            if (entry.optString("packageName") != sbn.packageName) continue

            val keywords = entry.optJSONArray("keywords")
            var matched = keywords == null || keywords.length() == 0
            if (!matched && keywords != null) {
                for (k in 0 until keywords.length()) {
                    val kw = keywords.optString(k)
                    if (kw.isNotBlank() && combined.contains(kw, ignoreCase = true)) {
                        matched = true
                        break
                    }
                }
            }
            if (matched) {
                showDetectedNotification(sbn.packageName, entry.optString("label", sbn.packageName), combined)
            }
            return
        }
    }

    private fun loadWatchList(): JSONArray? {
        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(CONFIG_KEY, null) ?: return null
        return try { JSONArray(raw) } catch (_: Exception) { null }
    }

    private fun showDetectedNotification(sourcePackage: String, sourceLabel: String, rawText: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Pagos detectados", NotificationManager.IMPORTANCE_HIGH)
            nm.createNotificationChannel(channel)
        }

        val notificationId = nextNotificationId++
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_PAYMENT_DETECTED, true)
            putExtra(MainActivity.EXTRA_PAYMENT_SOURCE_PACKAGE, sourcePackage)
            putExtra(MainActivity.EXTRA_PAYMENT_SOURCE_LABEL, sourceLabel)
            putExtra(MainActivity.EXTRA_PAYMENT_TEXT, rawText)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, notificationId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Posible pago detectado — $sourceLabel")
            .setContentText(rawText.take(120))
            .setStyle(Notification.BigTextStyle().bigText(rawText))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        nm.notify(notificationId, notification)
    }
}
