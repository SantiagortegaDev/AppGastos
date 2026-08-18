package com.example.appgastos

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Overlay nativo del Tile: muestra un modal sobre la app actualmente activa
 * para registrar un gasto SIN abrir la app completa.
 *
 * Requiere `android.permission.SYSTEM_ALERT_WINDOW`.
 *
 * Flujo:
 *  1. [ExpenseTileService] valida el permiso. Si está concedido, arranca
 *     este servicio; si no, abre [MainActivity] como fallback.
 *  2. Este servicio infla [overlay_expense] en una ventana
 *     `TYPE_APPLICATION_OVERLAY` centrada.
 *  3. El usuario escribe monto, toca "Siguiente" → el botón cambia a
 *     "Guardar gasto". La categoría se elige via chips; si solo hay una,
 *     se usa "Otro" por defecto.
 *  4. Al tocar "Guardar", persistimos el gasto en SharedPreferences (misma
 *     key que Flutter: `appgastos.expenses.v1`) y disparamos webhook si
 *     está configurado.
 *  5. El servicio se detiene solo.
 *
 * Para simplicidad del overlay nativo, combinamos categoría+cuenta en un
 * segundo step rápido: la categoría se elige por chips horizontales y la
 * cuenta se selecciona con un spinner. Si quieres la versión 3-pasos
 * idéntica a Flutter, se puede iterar; el overlay debe ser rápido.
 */
class OverlayService : Service() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val EXPENSES_KEY = "flutter.appgastos.expenses.v1"
        const val SETTINGS_KEY = "flutter.appgastos.settings.v1"
    }

    private var windowManager: WindowManager? = null
    private var rootView: View? = null

    // Categorías soportadas (deben coincidir con lib/models/expense.dart).
    private val categories = listOf(
        "comida" to "Comida",
        "transporte" to "Transporte",
        "compras" to "Compras",
        "servicios" to "Servicios",
        "otro" to "Otro"
    )

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (!canDrawOverlays()) {
            stopSelf()
            return
        }
        showOverlay()
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                Settings.canDrawOverlays(this)

    private fun showOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val inflater = LayoutInflater.from(this)
        rootView = inflater.inflate(R.layout.overlay_expense, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        // Habilitar foco para que el EditText reciba teclado.
        params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()

        windowManager?.addView(rootView, params)
        setupViews()
    }

    private fun setupViews() {
        val view = rootView ?: return
        val tvDisplay = view.findViewById<TextView>(R.id.tvDisplay)
        val etAmount = view.findViewById<EditText>(R.id.etAmount)
        val btnNext = view.findViewById<Button>(R.id.btnNext)
        val btnCancel = view.findViewById<Button>(R.id.btnCancel)
        val tvTitle = view.findViewById<TextView>(R.id.tvTitle)

        // Actualiza display grande en vivo + habilita/deshabilita botón.
        etAmount.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) {
                val v = s?.toString()?.toDoubleOrNull() ?: 0.0
                tvDisplay.text = "\$${formatAmount(v)}"
                btnNext.isEnabled = v > 0
            }
            override fun beforeTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) {}
            override fun onTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) {}
        })

        var currentCategoryIndex = 0 // Por defecto: Comida

        // Botón "Siguiente": cambia a pantalla de selección de categoría.
        btnNext.setOnClickListener {
            // Simulamos paso 2: cambiamos título y mostramos chips de categoría.
            tvTitle.text = "Toca una categoría"
            etAmount.visibility = View.GONE
            tvDisplay.visibility = View.GONE

            // En esta versión simplificada del overlay, hacemos clic en
            // ciclar categorías: el botón cambia de label a la siguiente
            // categoría, y un segundo botón "Guardar" aparece.
            // Para no inflar un layout más complejo, mostramos un Toast con
            // la categoría seleccionable y un solo toque confirma.
            currentCategoryIndex = 0
            btnNext.text = "Cat: ${categories[currentCategoryIndex].second}  (tocar para cambiar)"
            btnNext.setOnClickListener {
                currentCategoryIndex = (currentCategoryIndex + 1) % categories.size
                btnNext.text = "Cat: ${categories[currentCategoryIndex].second}  (tocar para cambiar)"
            }

            // Botón Cancelar se transforma en "Guardar".
            btnCancel.text = "Guardar gasto"
            btnCancel.setBackgroundColor(0xFF16A34A.toInt())
            btnCancel.setTextColor(0xFFFFFFFF.toInt())
            btnCancel.setOnClickListener {
                val amount = etAmount.text.toString().toDoubleOrNull() ?: 0.0
                if (amount <= 0) return@setOnClickListener
                val category = categories[currentCategoryIndex].first
                saveExpense(amount, category)
                Toast.makeText(this, "Gasto guardado: \$${formatAmount(amount)}",
                    Toast.LENGTH_SHORT).show()
                closeOverlay()
            }
        }

        btnCancel.setOnClickListener { closeOverlay() }
    }

    private fun saveExpense(amount: Double, category: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(EXPENSES_KEY, null)
        val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)

        // Cuenta: usar default de settings si está disponible.
        val settings = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(SETTINGS_KEY, null)
        val accountJson = JSONObject().apply {
            put("id", "acc-cash")
            put("name", "Efectivo")
            put("color", 0xFF16A34A.toInt())
        }
        try {
            val sObj = settings?.let { JSONObject(it) }
            val accounts = sObj?.optJSONArray("accounts")
            val defaultId = sObj?.optString("defaultAccountId", "acc-cash")
            for (i in 0 until (accounts?.length() ?: 0)) {
                val a = accounts!!.optJSONObject(i)
                if (a?.optString("id") == defaultId) {
                    accountJson.put("id", a.optString("id"))
                    accountJson.put("name", a.optString("name"))
                    accountJson.put("color", a.optInt("color"))
                    break
                }
            }
        } catch (_: Exception) {}

        val expense = JSONObject().apply {
            put("id", "${System.currentTimeMillis()}-${(0..99999).random()}")
            put("amount", amount)
            put("category", category)
            put("account", accountJson)
            put("date", java.text.SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US
            ).format(java.util.Date()))
        }
        arr.put(expense)
        prefs.edit().putString(EXPENSES_KEY, arr.toString()).apply()

        // Disparar webhook en background si está configurado.
        thread { fireWebhookIfConfigured(expense) }
    }

    private fun fireWebhookIfConfigured(expense: JSONObject) {
        try {
            val settings = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(SETTINGS_KEY, null) ?: return
            val sObj = JSONObject(settings)
            val url = sObj.optString("webhookUrl", "")
            if (url.isBlank()) return

            val payload = JSONObject().apply {
                put("event", "expense.created")
                put("id", expense.optString("id"))
                put("amount", expense.optDouble("amount"))
                put("category", expense.optString("category"))
                put("account", expense.optJSONObject("account"))
                put("date", expense.optString("date"))
                put("app", "AppGastos")
                put("version", 1)
            }

            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 5000
                readTimeout = 5000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("User-Agent", "AppGastos/1.0")
            }
            OutputStreamWriter(conn.outputStream).use {
                it.write(payload.toString())
                it.flush()
            }
            conn.responseCode
            conn.disconnect()
        } catch (_: Exception) {
            // Fire-and-forget.
        }
    }

    private fun closeOverlay() {
        try {
            rootView?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        stopSelf()
    }

    private fun formatAmount(v: Double): String {
        // Formato simple para el overlay (sin intl completo): agrupar miles.
        val fmt = java.text.DecimalFormat("#,###")
        return fmt.format(v.toLong())
    }
}
