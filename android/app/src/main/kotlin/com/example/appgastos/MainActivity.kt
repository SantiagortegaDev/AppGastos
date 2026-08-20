package com.example.appgastos

import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.service.quicksettings.TileService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity principal de la app Flutter.
 *
 * Responsabilidades:
 *  1. Detectar intent con `open_expense_sheet = true` (Tile → app).
 *     Si viene del Tile, aplica tema transparente para dar efecto overlay.
 *  2. Reenviar ese evento a Flutter via MethodChannel.
 *  3. Exponer `requestAddTile` (ACTION_QUICK_SETTINGS_ADD_TILE, API 33+).
 *  4. Exponer `requestListeningState` para refrescar el Tile.
 *  5. Exponer `finishApp` para que Flutter cierre la actividad
 *     después de guardar un gasto en modo transparente.
 */
class MainActivity : FlutterActivity() {

    // ── Transparencia: forzar TextureView para que soporte alpha ──
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.transparent

    companion object {
        const val CHANNEL_NAME = "appgastos.dev/tile"
        const val EXTRA_OPEN_EXPENSE_SHEET = "open_expense_sheet"
        private const val ACTION_QS_ADD_TILE = "android.service.quicksettings.action.QS_ADD_TILE"
        private const val TILE_COMPONENT_EXTRA = "android.service.quicksettings.extra.TILE_COMPONENT"
    }

    private var fromTile = false
    private var pendingOpenSheet = false
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    result.success(pendingOpenSheet)
                    pendingOpenSheet = false
                }
                "requestAddTile" -> result.success(tryRequestAddTile())
                "requestListeningState" -> {
                    tryRequestListeningState()
                    result.success(null)
                }
                "finishApp" -> {
                    finishAffinity()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOpenSheetIntent(intent, fromColdStart = false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        fromTile = intent?.getBooleanExtra(EXTRA_OPEN_EXPENSE_SHEET, false) == true
        if (fromTile) {
            // Reducir flash: aplicar antes de super.onCreate.
            setTheme(R.style.TransparentTheme)
        }
        super.onCreate(savedInstanceState)
        // FlutterActivity.onCreate() reemplaza el tema por NormalTheme internamente.
        // Re-aplicamos transparencia a nivel de tema + ventana DESPUÉS de super.
        if (fromTile) {
            setTheme(R.style.TransparentTheme)
            window.setBackgroundDrawable(ColorDrawable(0x00000000))
        }
        handleOpenSheetIntent(intent, fromColdStart = true)
    }

    private fun handleOpenSheetIntent(intent: Intent?, fromColdStart: Boolean) {
        val shouldOpen = intent?.getBooleanExtra(EXTRA_OPEN_EXPENSE_SHEET, false) == true
        if (!shouldOpen) return
        if (fromColdStart) {
            pendingOpenSheet = true
        } else {
            channel?.invokeMethod("openExpenseSheet", null)
        }
        intent?.removeExtra(EXTRA_OPEN_EXPENSE_SHEET)
    }

    private fun tryRequestAddTile(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        return try {
            val tileComponent = android.content.ComponentName(this, ExpenseTileService::class.java)
            val intent = Intent(ACTION_QS_ADD_TILE).apply {
                putExtra(TILE_COMPONENT_EXTRA, tileComponent)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun tryRequestListeningState() {
        try {
            TileService.requestListeningState(
                this,
                android.content.ComponentName(this, ExpenseTileService::class.java)
            )
        } catch (_: Exception) {}
    }
}
