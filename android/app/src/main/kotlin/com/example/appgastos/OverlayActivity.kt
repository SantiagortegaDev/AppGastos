package com.example.appgastos

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity translúcida usada por los Quick Settings Tiles: se dibuja
 * superpuesta sobre la app que esté abierta (la Activity anterior queda
 * pausada debajo, visible a través nuestro), corre un FlutterEngine propio
 * con el entrypoint `overlayMain` que muestra el mismo AddExpenseSheet que
 * la app normal, y se cierra sola al tocar afuera o al guardar el registro.
 */
class OverlayActivity : FlutterActivity() {

    companion object {
        const val CHANNEL_NAME = "appgastos.dev/overlay"
        const val EXTRA_TX_TYPE = "transaction_type"
    }

    private var channel: MethodChannel? = null

    override fun getDartEntrypointFunctionName(): String = "overlayMain"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getOverlayType" -> result.success(intent?.getStringExtra(EXTRA_TX_TYPE) ?: "")
                "finishOverlay" -> {
                    result.success(null)
                    finish()
                    @Suppress("DEPRECATION")
                    overridePendingTransition(0, 0)
                }
                else -> result.notImplemented()
            }
        }
    }
}
