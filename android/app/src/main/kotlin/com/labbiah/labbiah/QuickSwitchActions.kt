package com.labbiah.labbiah

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

/**
 * The two halves of Quick Switch, shared by both triggers:
 *  - Labbiah -> Android: case Home key + Volume Up held 5 s ([HomeVolumeCombo]).
 *  - Android -> Labbiah: Volume Up held 12 s ([QuickSwitchAccessibilityService]).
 */
object QuickSwitchActions {

    /** Hands off to the phone's own launcher (e.g. Samsung One UI Home).
     * Normally that's just the default Home app; once Labbiah *is* the
     * default, a plain CATEGORY_HOME intent would land back here, so the
     * other launcher is targeted directly instead. */
    fun goToRealHome(context: Context) {
        vibrate(context)
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            if (DefaultLauncher.isDefault(context)) {
                DefaultLauncher.otherLauncher(context)?.let { component = it }
            }
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /** Also used, without the buzz, to show Labbiah for a phone call and
     * to return to it when the call ends. */
    fun bringLabbiahToFront(context: Context, vibrate: Boolean = true) {
        if (vibrate) vibrate(context)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        context.startActivity(intent)
    }

    private fun vibrate(context: Context) {
        val vibrator = context.getSystemService(Vibrator::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(150)
        }
    }
}
