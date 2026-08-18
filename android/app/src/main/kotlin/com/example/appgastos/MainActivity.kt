package com.example.appgastos

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.service.quicksettings.TileService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity principal de la app Flutter.
 *
 * Responsabilidades adicionales (además de hostear Flutter):
 *  1. Detectar intent con `open_expense_sheet = true` (Tile → app abierta).
 *  2. Reenviar ese evento a Flutter via MethodChannel.
 *  3. Exponer `requestOverlayPermission` (SYSTEM_ALERT_WINDOW) al lado Dart.
 *  4. Exponer `requestAddTile` (ACTION_QUICK_SETTINGS_ADD_TILE, API 33+).
 *  5. Exponer `requestListeningState` para refrescar el Tile.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_NAME = "appgastos.dev/tile"
        const val EXTRA_OPEN_EXPENSE_SHEET = "open_expense_sheet"
        private const val ACTION_QS_ADD_TILE = "android.service.quicksettings.action.QS_ADD_TILE"
        private const val TILE_COMPONENT_EXTRA = "android.service.quicksettings.extra.TILE_COMPONENT"
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1001
    }

    private var pendingOpenSheet = false
    private var channel: MethodChannel? = null
    private var overlayPermissionCallback: ((Boolean) -> Unit)? = null

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
                "requestOverlayPermission" -> {
                    // Si ya tiene permiso, responde true inmediatamente.
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) {
                        result.success(true)
                    } else {
                        // Lanza intent ACTION_MANAGE_OVERLAY_PERMISSION y reporta al volver.
                        overlayPermissionCallback = { granted -> result.success(granted) }
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "canDrawOverlays" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
                )
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
        super.onCreate(savedInstanceState)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                    Settings.canDrawOverlays(this)
            overlayPermissionCallback?.invoke(granted)
            overlayPermissionCallback = null
        }
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
