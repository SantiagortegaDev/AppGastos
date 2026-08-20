package com.example.appgastos

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings Tile: abre la app con fondo transparente
 * (efecto overlay) para registrar un gasto rápido.
 *
 * Siempre lanza [MainActivity] con `open_expense_sheet = true`.
 * MainActivity aplica el tema transparente y Flutter muestra
 * directamente el bottom sheet de captura.
 */
class ExpenseTileService : TileService() {

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
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            putExtra(MainActivity.EXTRA_OPEN_EXPENSE_SHEET, true)
        }
        startActivityAndCollapse(launchIntent)
    }
}
