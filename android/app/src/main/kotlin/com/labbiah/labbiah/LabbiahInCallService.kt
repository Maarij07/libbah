package com.labbiah.labbiah

import android.os.PowerManager
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService

/**
 * Makes Labbiah the phone's call screen.
 *
 * Once Labbiah is the default Phone app, Android binds this service for
 * every incoming and outgoing call instead of opening its own dialer. The
 * call is then shown by Labbiah itself (Flutter's `CallScreen`), above the
 * case's real button bar, so Call answers and Hang-up declines or ends it
 * with no on-screen buttons at all. Android still plays the ringtone and
 * carries the audio — only the screen is Labbiah's.
 *
 * Labbiah is brought to the front when a call arrives, and again when the
 * last one ends, so the person always lands back on its home screen.
 *
 * During a call the phone's volume buttons choose where the sound comes
 * out — Volume Up for the loudspeaker, Volume Down for the earpiece (see
 * [setSpeaker]; [MainActivity] catches the buttons).
 *
 * Only one call at a time: a second caller is declined rather than shown.
 * Answering it would put the first call on hold, and the case has no key
 * to switch between two calls or bring a held one back.
 */
class LabbiahInCallService : InCallService() {

    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) = refresh()

        override fun onDetailsChanged(call: Call, details: Call.Details) = refresh()
    }

    // Turns the screen off against the ear, so a cheek can't press anything.
    private val proximityLock by lazy {
        getSystemService(PowerManager::class.java)?.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
            "labbiah:call",
        )
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    /** Loudspeaker on, or back to the earpiece (or a plugged-in headset). */
    fun setSpeaker(on: Boolean) {
        @Suppress("DEPRECATION")
        setAudioRoute(
            if (on) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_WIRED_OR_EARPIECE,
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onCallAudioStateChanged(audioState: CallAudioState?) {
        CallCenter.speakerOn = audioState?.route == CallAudioState.ROUTE_SPEAKER
        refresh()
    }

    override fun onCallAdded(call: Call) {
        if (CallCenter.current != null && CallCenter.stateOf(call) == Call.STATE_RINGING) {
            // Never tracked, so the call in progress isn't disturbed; the
            // phone's call log still records who rang.
            call.reject(false, null)
            return
        }
        call.registerCallback(callback)
        CallCenter.add(this, call)
        updateProximityLock()
        QuickSwitchActions.bringLabbiahToFront(this, vibrate = false)
    }

    override fun onCallRemoved(call: Call) {
        if (!CallCenter.isTracking(call)) return
        call.unregisterCallback(callback)
        CallCenter.remove(this, call)
        updateProximityLock()
        if (CallCenter.current == null) {
            QuickSwitchActions.bringLabbiahToFront(this, vibrate = false)
        }
    }

    override fun onDestroy() {
        instance = null
        CallCenter.speakerOn = false
        releaseProximityLock()
        super.onDestroy()
    }

    private fun refresh() {
        CallCenter.notifyChanged(this)
        updateProximityLock()
    }

    /** Held while talking or dialling at the ear. Not while ringing — the
     * screen has to stay on to show who is calling — nor on loudspeaker,
     * when the phone is held away from the face. */
    private fun updateProximityLock() {
        val call = CallCenter.current
        val talking = call != null &&
            CallCenter.stateOf(call) != Call.STATE_RINGING &&
            !CallCenter.speakerOn
        val lock = proximityLock ?: return
        if (talking && !lock.isHeld) {
            lock.acquire()
        } else if (!talking) {
            releaseProximityLock()
        }
    }

    private fun releaseProximityLock() {
        val lock = proximityLock ?: return
        if (lock.isHeld) lock.release()
    }

    companion object {
        /** The running service: set for as long as there is a call. */
        @Volatile
        var instance: LabbiahInCallService? = null
            private set
    }
}
