package com.example.appgastos

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.quicksettings.TileService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity principal de la app Flutter.
 *
 * Responsabilidades:
 *  1. Host del engine de Flutter (hereda de [FlutterActivity]).
 *  2. Detectar cuando el intent con el extra `open_expense_sheet = true`
 *     llega (cold-start vía `onCreate` / re-arranque vía `onNewIntent`).
 *  3. Reenviar ese evento a Flutter usando un [MethodChannel].
 *  4. Responder desde Flutter la llamada `getInitialAction()` para que la
 *     app sepa, al arrancar, si debe abrir automáticamente el bottom sheet.
 *  5. Exponer los métodos `requestAddTile` y `requestListeningState` que
 *     usa el lado Dart para interactuar con el Tile nativo.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_NAME = "appgastos.dev/tile"
        const val EXTRA_OPEN_EXPENSE_SHEET = "open_expense_sheet"

        // Llave del intent nativo para ACTION_QUICK_SETTINGS_ADD_TILE (Android 13+).
        private const val ACTION_QS_ADD_TILE = "android.service.quicksettings.action.QS_ADD_TILE"
        private const val TILE_COMPONENT_EXTRA = "android.service.quicksettings.extra.TILE_COMPONENT"
    }

    private var pendingOpenSheet = false
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    // Reporta si el arranque se produjo por un toque en el Tile.
                    result.success(pendingOpenSheet)
                    pendingOpenSheet = false
                }
                "requestAddTile" -> {
                    // Intenta invocar el asistente nativo "Agregar tile" (Android 13+).
                    val launched = tryRequestAddTile()
                    result.success(launched)
                }
                "requestListeningState" -> {
                    tryRequestListeningState()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Detecta el extra en el intent inicial (cold-start).
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOpenSheetIntent(intent, fromColdStart = false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleOpenSheetIntent(intent, fromColdStart = true)
    }

    private fun handleOpenSheetIntent(intent: Intent?, fromColdStart: Boolean) {
        val shouldOpen = intent?.getBooleanExtra(EXTRA_OPEN_EXPENSE_SHEET, false) == true
        if (!shouldOpen) return

        if (fromColdStart) {
            // Flutter todavía no está listo: guardamos el flag para responder
            // cuando llegue la llamada `getInitialAction`.
            pendingOpenSheet = true
        } else {
            // App ya en foreground: notificamos en vivo.
            channel?.invokeMethod("openExpenseSheet", null)
        }

        // Limpiamos el extra para que no se "repita" en futuros onNewIntent.
        intent?.removeExtra(EXTRA_OPEN_EXPENSE_SHEET)
    }

    /**
     * Lanza el intent oficial `ACTION_QUICK_SETTINGS_ADD_TILE` (API 33+).
     * Muestra un diálogo del sistema pidiendo al usuario que agregue el tile.
     */
    private fun tryRequestAddTile(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        return try {
            val tileComponent = android.content.ComponentName(
                this,
                ExpenseTileService::class.java
            )
            val intent = Intent(ACTION_QS_ADD_TILE).apply {
                putExtra(TILE_COMPONENT_EXTRA, tileComponent)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Solicita al sistema un refresh del estado del tile (label/icon/state).
     */
    private fun tryRequestListeningState() {
        try {
            TileService.requestListeningState(
                this,
                android.content.ComponentName(this, ExpenseTileService::class.java)
            )
        } catch (_: Exception) {
            // Ignoramos errores silenciosamente.
        }
    }
}
