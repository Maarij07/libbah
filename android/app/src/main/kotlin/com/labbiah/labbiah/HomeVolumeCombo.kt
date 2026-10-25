package com.labbiah.labbiah

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Leaves Labbiah for the regular Android home screen when the case's
 * on-screen Home key and the physical Volume Up button are both held for
 * 5 seconds.
 *
 * Only runs while Labbiah is on screen, so it needs no special permission:
 * [MainActivity] sees Volume Up itself, and Flutter reports the Home key
 * via [setHomeHeld]. The 5 s are timed from the moment both are down, in
 * whichever order they were pressed; releasing either one cancels it.
 */
class HomeVolumeCombo(private val context: Context) {

    private val handler = Handler(Looper.getMainLooper())
    private val fire = Runnable { QuickSwitchActions.goToRealHome(context) }

    private var homeHeld = false
    private var volumeUpHeld = false

    /** Told when Volume Up goes down or up, so Labbiah can show it as
     * pressed next to its own Home key. */
    var onVolumeUpChanged: ((Boolean) -> Unit)? = null

    /** Whether Volume Up was pressed at any point during the current Home
     * hold — lets Flutter tell a combo apart from a plain long-press. */
    var volumeUpDuringHomeHold = false
        private set

    fun setHomeHeld(held: Boolean) {
        homeHeld = held
        if (held) volumeUpDuringHomeHold = volumeUpHeld
        update()
    }

    fun setVolumeUpHeld(held: Boolean) {
        // Auto-repeat re-sends key-down while held; only the first counts.
        if (held == volumeUpHeld) return
        volumeUpHeld = held
        if (held && homeHeld) volumeUpDuringHomeHold = true
        onVolumeUpChanged?.invoke(held)
        update()
    }

    /** Called when Labbiah's window loses focus: a key-up may never arrive. */
    fun reset() {
        homeHeld = false
        if (volumeUpHeld) onVolumeUpChanged?.invoke(false)
        volumeUpHeld = false
        update()
    }

    private fun update() {
        handler.removeCallbacks(fire)
        if (homeHeld && volumeUpHeld) handler.postDelayed(fire, HOLD_MILLIS)
    }

    companion object {
        private const val HOLD_MILLIS = 5_000L
    }
}
