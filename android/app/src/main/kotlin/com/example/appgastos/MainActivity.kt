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
 * Activity principal.
 *
 * - Detecta intent con extras del Tile (open_expense_sheet + transaction_type).
 * - Reenvía el evento a Flutter via MethodChannel.
 * - Expone requestAddTile (API 33+) y finishApp.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_NAME = "appgastos.dev/tile"
        const val EXTRA_OPEN_SHEET = "open_expense_sheet"
        const val EXTRA_TX_TYPE = "transaction_type"
        private const val ACTION_QS_ADD_TILE = "android.service.quicksettings.action.QS_ADD_TILE"
        private const val TILE_COMPONENT_EXTRA = "android.service.quicksettings.extra.TILE_COMPONENT"
    }

    private var pendingOpenSheet = false
    private var pendingType: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    val map = mapOf(
                        "open" to pendingOpenSheet,
                        "type" to (pendingType ?: "")
                    )
                    pendingOpenSheet = false
                    pendingType = null
                    result.success(map)
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
        handleSheetIntent(intent, coldStart = false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleSheetIntent(intent, coldStart = true)
    }

    private fun handleSheetIntent(intent: Intent?, coldStart: Boolean) {
        val shouldOpen = intent?.getBooleanExtra(EXTRA_OPEN_SHEET, false) == true
        if (!shouldOpen) return

        val type = intent?.getStringExtra(EXTRA_TX_TYPE)  // "gasto", "ingreso" o null
        if (coldStart) {
            pendingOpenSheet = true
            pendingType = type
        } else {
            channel?.invokeMethod("openExpenseSheet", type)
        }
        intent?.removeExtra(EXTRA_OPEN_SHEET)
        intent?.removeExtra(EXTRA_TX_TYPE)
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
