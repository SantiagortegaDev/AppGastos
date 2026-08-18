package com.example.appgastos

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings Tile nativo para abrir el flujo "Registrar gasto".
 *
 * Puntos clave:
 *  - Se registra en `AndroidManifest.xml` con permiso
 *    `android.permission.BIND_QUICK_SETTINGS_TILE` y action
 *    `android.service.quicksettings.action.QS_TILE`.
 *  - No funciona como toggle permanente: cada toque lanza la app.
 *    Por eso, el estado del tile se mantiene en [Tile.STATE_INACTIVE]
 *    en cada `onStartListening`.
 *  - Al hacer click, enviamos un intent a [MainActivity] con el extra
 *    `open_expense_sheet = true`, que es el puente hacia Flutter.
 */
class ExpenseTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        // Mantenemos el tile en estado INACTIVE porque no es un toggle,
        // es un "lanzador" directo del flujo de captura.
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Registrar gasto"
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()

        // Intent explícito a MainActivity, con el extra que indica que debe
        // abrir el bottom sheet de captura automáticamente.
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_OPEN_EXPENSE_SHEET, true)
        }
        startActivityAndCollapse(launchIntent)
    }
}
