package com.example.appgastos

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Tile: Registrar (abre el modal con selección de gasto/ingreso). */
class RegisterTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Registrar"
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        startActivityAndCollapse(
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.EXTRA_OPEN_SHEET, true)
                // Sin EXTRA_TX_TYPE → Flutter muestra la selección.
            }
        )
    }
}
