package com.labbiah.labbiah

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout

/**
 * Labbiah's button bar, drawn over the phone's own call screen.
 *
 * The case's physical buttons press fixed spots on the touchscreen, and
 * during a call those spots are covered by the dialer rather than by
 * Labbiah. This puts a copy of the bar back under them — same size and
 * position as Flutter's `PhoneCase` — so Hang-up ends (or rejects) the
 * call and Call answers it. The other four keys are drawn blank and just
 * swallow the press, so a stray button can't mute or hold the call
 * through the dialer underneath.
 *
 * It is an accessibility overlay, so it needs no "display over other apps"
 * permission and also shows over the lock screen, where incoming calls
 * ring full-screen.
 */
class CallCaseOverlay(private val service: AccessibilityService) {

    private val windowManager = service.getSystemService(WindowManager::class.java)
    private var view: View? = null

    fun show() {
        if (view != null) return
        val bar = buildBar()
        try {
            windowManager.addView(bar, layoutParams())
            view = bar
        } catch (_: WindowManager.BadTokenException) {
            // The service is being torn down; nothing to draw on.
        }
    }

    fun hide() {
        val bar = view ?: return
        view = null
        try {
            windowManager.removeView(bar)
        } catch (_: IllegalArgumentException) {
            // Already gone along with the service's window token.
        }
    }

    /** Mirrors `PhoneShell`: the bar is the bottom 3/10 of the safe area. */
    private fun layoutParams(): WindowManager.LayoutParams {
        val screenHeight: Int
        val top: Int
        val bottom: Int
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = windowManager.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            screenHeight = metrics.bounds.height()
            top = insets.top
            bottom = insets.bottom
        } else {
            val size = android.graphics.Point()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealSize(size)
            screenHeight = size.y
            top = systemDimension("status_bar_height")
            bottom = systemDimension("navigation_bar_height")
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            (screenHeight - top - bottom) * 3 / 10,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            // Not focusable, so the dialer keeps the volume keys and Back.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM
            y = bottom
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Measure from the true screen edge, not from the nav bar.
                fitInsetsTypes = 0
            }
        }
    }

    private fun systemDimension(name: String): Int {
        val resources = service.resources
        val id = resources.getIdentifier(name, "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else 0
    }

    private fun buildBar(): View {
        val bar = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            // The keys sit under fixed physical buttons, so their order
            // never mirrors in RTL languages.
            layoutDirection = View.LAYOUT_DIRECTION_LTR
            setBackgroundColor(Color.parseColor("#E4E4E4"))
            setPadding(dp(10), dp(10), dp(10), dp(10))
            // Swallow presses that land between keys.
            isClickable = true
        }
        bar.addView(
            row(
                key(R.drawable.ic_case_hangup, R.string.case_hangup) {
                    CallControl.endIfInCall(service)
                },
                blankKey(),
                key(R.drawable.ic_case_call, R.string.case_call) {
                    CallControl.answerIfRinging(service)
                },
            ),
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f),
        )
        bar.addView(
            row(blankKey(), blankKey(), blankKey()),
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f).apply {
                topMargin = dp(10)
            },
        )
        return bar
    }

    private fun row(vararg keys: View): LinearLayout {
        val row = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_LTR
        }
        for (key in keys) {
            row.addView(
                key,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f).apply {
                    leftMargin = dp(5)
                    rightMargin = dp(5)
                },
            )
        }
        return row
    }

    private fun key(icon: Int, label: Int, onPressed: () -> Unit): View {
        return FrameLayout(service).apply {
            background = keyBackground()
            elevation = dp(1.5f)
            contentDescription = service.getString(label)
            setOnClickListener { onPressed() }
            addView(
                ImageView(service).apply { setImageResource(icon) },
                FrameLayout.LayoutParams(dp(52), dp(52), Gravity.CENTER),
            )
        }
    }

    /** A key that does nothing during a call, shown faded to say so. */
    private fun blankKey(): View {
        return View(service).apply {
            background = keyBackground()
            alpha = 0.45f
            isClickable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
    }

    private fun keyBackground() = GradientDrawable().apply {
        setColor(Color.WHITE)
        cornerRadius = dp(14f)
        setStroke(dp(1), Color.parseColor("#E0E0E0"))
    }

    private fun dp(value: Int): Int = dp(value.toFloat()).toInt()

    private fun dp(value: Float): Float = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value,
        service.resources.displayMetrics,
    )
}
