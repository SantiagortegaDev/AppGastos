package com.example.appgastos

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService

/**
 * A partir de Android 14 (API 34), `TileService.startActivityAndCollapse(Intent)`
 * está deprecado y ADEMÁS lanza `UnsupportedOperationException` en apps con
 * targetSdk 34+ (la nuestra) — hay que usar la variante con `PendingIntent`.
 * En versiones viejas esa variante no existe, así que se usa el fallback.
 */
fun TileService.launchOverlay(intent: Intent, requestCode: Int) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        val pendingIntent = PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        startActivityAndCollapse(pendingIntent)
    } else {
        @Suppress("DEPRECATION")
        startActivityAndCollapse(intent)
    }
}
