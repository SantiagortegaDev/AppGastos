package com.example.appgastos

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings Tile nativo para abrir el flujo "Registrar gasto".
 *
 * Comportamiento:
 *  - Si el usuario activó "Modal sobre otras apps" en Settings Y tiene
 *    concedido el permiso SYSTEM_ALERT_WINDOW, arranca [OverlayService].
 *  - En caso contrario, lanza [MainActivity] con el extra
 *    `open_expense_sheet = true` (flujo clásico).
 *
 * El flag "overlay habilitado" se lee de SharedPreferences (misma key
 * que Flutter: `flutter.appgastos.settings.v1`).
 */
class ExpenseTileService : TileService() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val SETTINGS_KEY = "flutter.appgastos.settings.v1"
    }

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Registrar gasto"
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()

        val overlayEnabled = isOverlayEnabled()
        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            Settings.canDrawOverlays(this) else true

        if (overlayEnabled && canDraw) {
            // Modal sobre la app activa.
            val intent = Intent(this, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } else {
            // Fallback: abrir app con el bottom sheet.
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.EXTRA_OPEN_EXPENSE_SHEET, true)
            }
            startActivityAndCollapse(launchIntent)
        }
    }

    private fun isOverlayEnabled(): Boolean {
        return try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val raw = prefs.getString(SETTINGS_KEY, null) ?: return false
            val obj = org.json.JSONObject(raw)
            obj.optBoolean("overlayEnabled", false)
        } catch (_: Exception) {
            false
        }
    }
}
