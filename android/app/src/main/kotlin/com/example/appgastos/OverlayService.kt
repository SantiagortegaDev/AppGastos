package com.example.appgastos

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.transition.*
import android.view.*
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.AccelerateInterpolator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread

/**
 * Overlay nativo del Tile: replica visual y funcional del
 * `AddExpenseSheet` de Flutter (Material 3, 3 pasos, AnimatedSize).
 *
 * Paso 1 – Monto:  título, display grande del monto, TextField, botón "Siguiente".
 * Paso 2 – Categoría: resumen del monto, chips de categoría (ChoiceChip).
 * Paso 3 – Cuenta:   resumen + categoría, chips de cuenta (ActionChip).
 *
 * La ventana se posiciona en la parte inferior con esquinas superiores
 * redondeadas (28 dp) para imitar `showModalBottomSheet`.
 */
class OverlayService : Service() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val EXPENSES_KEY = "flutter.appgastos.expenses.v1"
        const val SETTINGS_KEY = "flutter.appgastos.settings.v1"
        private const val DEFAULT_PRIMARY = 0xFF16A34A.toInt()
    }

    /* ── Data ─────────────────────────────────────────────── */
    private data class CatItem(val key: String, val label: String, val emoji: String)
    private data class AccItem(val id: String, val name: String, val color: Int)

    private val categories = listOf(
        CatItem("comida", "Comida", "\uD83C\uDF7D"),
        CatItem("transporte", "Transporte", "\uD83D\uDE8C"),
        CatItem("compras", "Compras", "\uD83D\uDECD"),
        CatItem("servicios", "Servicios", "\uD83D\uDCCB"),
        CatItem("otro", "Otro", "\uD83D\uDCE6"),
    )

    /* ── State ────────────────────────────────────────────── */
    private var currentStep = 1
    private var enteredAmount = 0.0
    private var selectedCatIdx = 0
    private var accounts = emptyList<AccItem>()
    private var primaryColor = DEFAULT_PRIMARY

    /* ── Window / views ───────────────────────────────────── */
    private var wm: WindowManager? = null
    private var sheetFrame: FrameLayout? = null
    private var contentBox: LinearLayout? = null
    private var step1View: LinearLayout? = null
    private var step2View: LinearLayout? = null
    private var step3View: LinearLayout? = null
    private var tvDisplay1: TextView? = null
    private var tvDisplay2: TextView? = null
    private var tvDisplay3: TextView? = null
    private var etAmount: EditText? = null
    private var btnNext: View? = null
    private var saving = false

    /* ── Lifecycle ────────────────────────────────────────── */
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (!canDrawOverlays()) { stopSelf(); return }
        loadSettings()
        showOverlay()
    }

    /* ── Settings ─────────────────────────────────────────── */
    private fun loadSettings() {
        try {
            val raw = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .getString(SETTINGS_KEY, null) ?: return
            val obj = JSONObject(raw)
            primaryColor = obj.optLong("seedColor", DEFAULT_PRIMARY.toLong()).toInt()
            val arr = obj.optJSONArray("accounts")
            if (arr != null) {
                accounts = (0 until arr.length()).map { i ->
                    val a = arr.getJSONObject(i)
                    AccItem(a.getString("id"), a.getString("name"),
                        a.optLong("color", DEFAULT_PRIMARY.toLong()).toInt())
                }
            }
        } catch (_: Exception) {}
    }

    /* ── Overlay window ───────────────────────────────────── */
    @SuppressLint("ClickableViewAccessibility")
    private fun showOverlay() {
        wm = getSystemService(WINDOW_SERVICE) as WindowManager

        // --- Sheet container (bottom-sheet look) ---
        sheetFrame = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                cornerRadii = floatArrayOf(
                    28.dpF, 28.dpF, 28.dpF, 28.dpF,   // top-left & top-right
                    0f, 0f, 0f, 0f                       // bottom corners square
                )
                setColor(Color.WHITE)
            }
            elevation = 12.dpF
        }

        // --- Content area (Flutter padding: 20,12,20,24) ---
        contentBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20.dp, 12.dp, 20.dp, 24.dp)
        }
        sheetFrame!!.addView(contentBox)

        // --- Build 3 steps ---
        step1View = buildStep1()
        step2View = buildStep2()
        step3View = buildStep3()
        step2View!!.visibility = View.GONE
        step3View!!.visibility = View.GONE
        contentBox!!.addView(step1View)
        contentBox!!.addView(step2View)
        contentBox!!.addView(step3View)

        // --- Window params ---
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_DIM_BEHIND
                    or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM
            dimAmount = 0.5f
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            // Remove FLAG_NOT_FOCUSABLE so the EditText can receive focus
            // (start from the flags above and ensure NOT_FOCUSABLE is NOT set)
        }

        wm?.addView(sheetFrame, params)

        // --- Back-key handling ---
        sheetFrame!!.isFocusableInTouchMode = true
        sheetFrame!!.requestFocus()
        sheetFrame!!.setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                when (currentStep) {
                    1 -> closeOverlay()
                    2 -> goStep(1)
                    3 -> goStep(2)
                }
                true
            } else false
        }

        // --- Enter animation (slide up) ---
        sheetFrame!!.post {
            val h = sheetFrame!!.height.toFloat()
            sheetFrame!!.translationY = h
            sheetFrame!!.alpha = 0f
            sheetFrame!!.animate()
                .translationY(0f)
                .alpha(1f)
                .setDuration(300)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .start()
        }

        // Open keyboard on step 1
        etAmount?.postDelayed({
            etAmount?.requestFocus()
            val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(etAmount, InputMethodManager.SHOW_IMPLICIT)
        }, 350)
    }

    /* ── Step 1: Monto ────────────────────────────────────── */
    private fun buildStep1(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )

            // Drag handle
            addView(buildDragHandle())

            // Title
            addView(TextView(this@OverlayService).apply {
                text = "¿Cuánto gastaste?"
                textSize = 22f
                setTextColor(Color.parseColor("#111111"))
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            })

            addView(space(24))

            // Amount display container
            tvDisplay1 = TextView(this@OverlayService).apply {
                text = "\$0"
                textSize = 40f
                setTextColor(Color.parseColor("#888888"))
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(24.dp, 16.dp, 24.dp, 16.dp)
                background = GradientDrawable().apply {
                    cornerRadius = 20.dpF
                    setColor(Color.parseColor("#F0F0F0"))
                }
                layoutParams = lpMatchWrap()
            }
            addView(tvDisplay1)

            addView(space(12))

            // Amount input
            etAmount = EditText(this@OverlayService).apply {
                hint = "Escribe el monto"
                textSize = 18f
                gravity = Gravity.CENTER
                inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                setPadding(20.dp, 18.dp, 20.dp, 18.dp)
                background = GradientDrawable().apply {
                    cornerRadius = 16.dpF
                    setColor(Color.TRANSPARENT)
                    setStroke(2.dp, Color.parseColor("#CCCCCC"))
                }
                setOnEditorActionListener { _, actionId, _ ->
                    if (actionId == EditorInfo.IME_ACTION_NEXT) goNext()
                    true
                }
                addTextChangedListener(object : TextWatcher {
                    override fun afterTextChanged(s: Editable?) {
                        val v = s?.toString()?.toDoubleOrNull() ?: 0.0
                        enteredAmount = v
                        tvDisplay1?.text = "\$${formatAmount(v)}"
                        tvDisplay1?.setTextColor(
                            if (v > 0) primaryColor
                            else Color.parseColor("#888888")
                        )
                        updateNextButton(v > 0)
                    }
                    override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
                    override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
                })
                layoutParams = lpMatchWrap()
            }
            addView(etAmount)

            addView(space(16))

            // "Siguiente" FilledButton
            btnNext = buildFilledButton("Siguiente  →", enabled = false) { goNext() }
            addView(btnNext)
        }
    }

    /* ── Step 2: Categoría ────────────────────────────────── */
    private fun buildStep2(): LinearLayout {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )

            addView(buildDragHandle())

            // Subtitle
            addView(TextView(this@OverlayService).apply {
                text = "Gasto a registrar"
                textSize = 14f
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            })

            addView(space(4))

            // Amount
            tvDisplay2 = TextView(this@OverlayService).apply {
                textSize = 30f
                setTextColor(primaryColor)
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            }
            addView(tvDisplay2)

            addView(space(20))

            // Category title
            addView(TextView(this@OverlayService).apply {
                text = "¿En qué categoría?"
                textSize = 18f
                setTextColor(Color.parseColor("#111111"))
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            })

            addView(space(16))

            // Category chips container (built dynamically later)
            addView(space(16))

            // Back button
            addView(buildTextButton("←  Cambiar monto") { goStep(1) })
        }

        // Build category chips and insert them
        val chipsContainer = buildCategoryChips()
        val insertIdx = box.childCount - 1 // before the back button
        box.addView(chipsContainer, insertIdx)

        return box
    }

    /* ── Step 3: Cuenta ───────────────────────────────────── */
    private fun buildStep3(): LinearLayout {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )

            addView(buildDragHandle())

            // Subtitle
            addView(TextView(this@OverlayService).apply {
                text = "Gasto a registrar"
                textSize = 14f
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            })

            addView(space(4))

            // Amount
            tvDisplay3 = TextView(this@OverlayService).apply {
                textSize = 30f
                setTextColor(primaryColor)
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            }
            addView(tvDisplay3)

            addView(space(8))

            // Category label
            val tvCat = TextView(this@OverlayService).apply {
                textSize = 16f
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
                tag = "tvCategoryLabel"
            }
            addView(tvCat)

            addView(space(20))

            // Account title
            addView(TextView(this@OverlayService).apply {
                text = "¿Desde qué cuenta?"
                textSize = 18f
                setTextColor(Color.parseColor("#111111"))
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = lpMatchWrap()
            })

            addView(space(16))

            // Account chips container
            addView(space(16))

            // Back button
            addView(buildTextButton("←  Cambiar categoría") { goStep(2) })
        }

        // Build account chips and insert them
        val chipsContainer = buildAccountChips()
        val insertIdx = box.childCount - 1
        box.addView(chipsContainer, insertIdx)

        return box
    }

    /* ── Category chips ───────────────────────────────────── */
    private fun buildCategoryChips(): LinearLayout {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = lpMatchWrap()
        }

        val chipViews = categories.mapIndexed { idx, cat ->
            createChip(
                text = cat.label,
                emoji = cat.emoji,
                isSelected = idx == selectedCatIdx
            ) {
                selectedCatIdx = idx
                // Refresh selection visuals
                refreshCategoryChips()
                // Auto-advance to step 3 (matching Flutter behavior)
                goStep(3)
            }
        }

        // Arrange chips in rows (max 3 per row)
        chipViews.chunked(3).forEach { rowChips ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 12.dp }
            }
            rowChips.forEachIndexed { i, chip ->
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                if (i < rowChips.size - 1) params.rightMargin = 12.dp
                row.addView(chip, params)
            }
            container.addView(row)
        }

        return container
    }

    /** Refresh category chip selection visuals after index change. */
    private fun refreshCategoryChips() {
        val step2 = step2View ?: return
        val chipsBox = step2.getChildAt(step2.childCount - 2) // chips container
        if (chipsBox !is LinearLayout) return
        var chipIdx = 0
        for (i in 0 until chipsBox.childCount) {
            val row = chipsBox.getChildAt(i) as? LinearLayout ?: continue
            for (j in 0 until row.childCount) {
                val tv = row.getChildAt(j) as? TextView ?: continue
                val sel = chipIdx == selectedCatIdx
                tv.setTextColor(if (sel) primaryColor else Color.parseColor("#DD000000"))
                (tv.background as? GradientDrawable)?.let { bg ->
                    bg.setColor(if (sel) primaryColorWithAlpha(26) else Color.parseColor("#0D000000"))
                    if (sel) bg.setStroke(2.dp, primaryColor) else bg.setStroke(0, Color.TRANSPARENT)
                }
                chipIdx++
            }
        }
    }

    /* ── Account chips ────────────────────────────────────── */
    private fun buildAccountChips(): LinearLayout {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = lpMatchWrap()
        }

        if (accounts.isEmpty()) {
            container.addView(TextView(this@OverlayService).apply {
                text = "No tienes cuentas configuradas."
                textSize = 14f
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                setPadding(16.dp, 16.dp, 16.dp, 16.dp)
            })
            return container
        }

        val chipViews = accounts.map { acc ->
            createChip(
                text = acc.name,
                colorDot = acc.color,
                isSelected = false
            ) {
                if (saving) return@createChip
                saveExpense(enteredAmount, categories[selectedCatIdx].key, acc)
                Toast.makeText(this@OverlayService,
                    "Gasto guardado: \$${formatAmount(enteredAmount)}",
                    Toast.LENGTH_SHORT).show()
                closeOverlay()
            }
        }

        chipViews.chunked(3).forEach { rowChips ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 12.dp }
            }
            rowChips.forEachIndexed { i, chip ->
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                if (i < rowChips.size - 1) params.rightMargin = 12.dp
                row.addView(chip, params)
            }
            container.addView(row)
        }

        return container
    }

    /* ── UI helpers ───────────────────────────────────────── */

    private fun buildDragHandle(): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(40.dp, 4.dp).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = 16.dp
            }
            background = GradientDrawable().apply {
                cornerRadius = 2.dpF
                setColor(Color.parseColor("#C4C4C4"))
            }
        }
    }

    private fun createChip(
        text: String,
        emoji: String? = null,
        colorDot: Int? = null,
        isSelected: Boolean = false,
        onClick: () -> Unit
    ): TextView {
        val chip = TextView(this).apply {
            this.text = text
            textSize = 16f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(20.dp, 14.dp, 20.dp, 14.dp)
            setTextColor(if (isSelected) primaryColor else Color.parseColor("#DD000000"))

            // Icon (emoji or color dot)
            val icon = when {
                emoji != null -> emojiDrawable(emoji, 24.dp)
                colorDot != null -> colorDotDrawable(colorDot, 24.dp)
                else -> null
            }
            if (icon != null) {
                setCompoundDrawablesRelativeWithIntrinsicBounds(icon, null, null, null)
                compoundDrawablePadding = 8.dp
            }

            background = GradientDrawable().apply {
                cornerRadius = 16.dpF
                setColor(if (isSelected) primaryColorWithAlpha(26) else Color.parseColor("#0D000000"))
                if (isSelected) setStroke(2.dp, primaryColor)
                else setStroke(0, Color.TRANSPARENT)
            }

            setOnClickListener { onClick() }
            isClickable = true
        }
        return chip
    }

    private fun buildFilledButton(text: String, enabled: Boolean, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 16f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            setTextColor(if (enabled) Color.WHITE else Color.argb(97, 255, 255, 255))
            setPadding(16.dp, 0, 16.dp, 0)
            minHeight = 54.dp
            background = GradientDrawable().apply {
                cornerRadius = 16.dpF
                setColor(if (enabled) primaryColor else primaryColorWithAlpha(38))
            }
            isClickable = enabled
            setOnClickListener { if (enabled) onClick() }
            tag = "btnFilled"
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun buildTextButton(text: String, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 14f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            setTextColor(primaryColor)
            gravity = Gravity.CENTER
            setPadding(12.dp, 8.dp, 12.dp, 8.dp)
            isClickable = true
            setOnClickListener { onClick() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER_HORIZONTAL }
        }
    }

    /** Update the "Siguiente" button enabled state. */
    private fun updateNextButton(enabled: Boolean) {
        val btn = btnNext as? TextView ?: return
        btn.isClickable = enabled
        btn.setTextColor(if (enabled) Color.WHITE else Color.argb(97, 255, 255, 255))
        (btn.background as? GradientDrawable)?.setColor(
            if (enabled) primaryColor else primaryColorWithAlpha(38)
        )
    }

    /* ── Drawables ────────────────────────────────────────── */

    private fun emojiDrawable(emoji: String, sizePx: Int): BitmapDrawable {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = sizePx * 0.7f
            textAlign = Paint.Align.CENTER
        }
        val y = (canvas.height / 2f) - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(emoji, canvas.width / 2f, y, paint)
        return BitmapDrawable(resources, bitmap)
    }

    private fun colorDotDrawable(color: Int, sizePx: Int): BitmapDrawable {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.FILL
        }
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, paint)
        return BitmapDrawable(resources, bitmap)
    }

    /* ── Navigation ───────────────────────────────────────── */

    private fun goNext() {
        val v = enteredAmount
        if (v <= 0) return
        hideKeyboard()
        goStep(2)
    }

    private fun goStep(step: Int) {
        val box = contentBox ?: return

        // Update amount displays for steps 2 & 3
        val amountStr = "\$${formatAmount(enteredAmount)}"
        tvDisplay2?.text = amountStr
        tvDisplay3?.text = amountStr

        // Update category label in step 3
        if (step == 3) {
            step3View?.findViewWithTag<TextView>("tvCategoryLabel")
                ?.text = categories[selectedCatIdx].label
        }

        // Animate transition (matches Flutter AnimatedSize 250ms easeInOut)
        val transition = TransitionSet().apply {
            ordering = TransitionSet.ORDERING_TOGETHER
            addTransition(ChangeBounds().setDuration(250))
            addTransition(Fade(Fade.IN).setDuration(200))
            addTransition(Fade(Fade.OUT).setDuration(150))
            interpolator = AccelerateDecelerateInterpolator()
        }
        TransitionManager.beginDelayedTransition(box, transition)

        step1View?.visibility = if (step == 1) View.VISIBLE else View.GONE
        step2View?.visibility = if (step == 2) View.VISIBLE else View.GONE
        step3View?.visibility = if (step == 3) View.VISIBLE else View.GONE
        currentStep = step
    }

    /* ── Save expense ─────────────────────────────────────── */
    private fun saveExpense(amount: Double, category: String, account: AccItem) {
        if (saving) return
        saving = true

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val raw = prefs.getString(EXPENSES_KEY, null)
        val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)

        val expense = JSONObject().apply {
            put("id", "${System.currentTimeMillis()}-${(0..99999).random()}")
            put("amount", amount)
            put("category", category)
            put("account", JSONObject().apply {
                put("id", account.id)
                put("name", account.name)
                put("color", account.color)
            })
            put("date", SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US
            ).format(Date()))
        }
        arr.put(expense)
        prefs.edit().putString(EXPENSES_KEY, arr.toString()).apply()

        // Webhook fire-and-forget
        thread { fireWebhookIfConfigured(expense) }
    }

    private fun fireWebhookIfConfigured(expense: JSONObject) {
        try {
            val settings = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
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
        } catch (_: Exception) {}
    }

    /* ── Close ────────────────────────────────────────────── */
    private fun closeOverlay() {
        hideKeyboard()
        val sheet = sheetFrame ?: run { stopSelf(); return }
        sheet.animate()
            .translationY(sheet.height.toFloat())
            .alpha(0f)
            .setDuration(250)
            .setInterpolator(AccelerateInterpolator())
            .withEndAction {
                try { sheet.let { wm?.removeView(it) } } catch (_: Exception) {}
                stopSelf()
            }
            .start()
    }

    /* ── Utilities ────────────────────────────────────────── */

    private fun hideKeyboard() {
        etAmount?.let {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.hideSoftInputFromWindow(it.windowToken, 0)
            it.clearFocus()
        }
    }

    private fun formatAmount(v: Double): String = DecimalFormat("#,###").format(v.toLong())

    private fun primaryColorWithAlpha(alpha: Int): Int {
        val r = Color.red(primaryColor)
        val g = Color.green(primaryColor)
        val b = Color.blue(primaryColor)
        return Color.argb(alpha, r, g, b)
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun space(dp: Int): Space {
        return Space(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp
            )
        }
    }

    private fun lpMatchWrap() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )

    private val Int.dp: Int get() = (this * resources.displayMetrics.density + 0.5f).toInt()
    private val Int.dpF: Float get() = this * resources.displayMetrics.density
}
