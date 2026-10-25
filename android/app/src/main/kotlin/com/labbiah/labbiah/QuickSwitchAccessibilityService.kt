package com.labbiah.labbiah

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * Brings Labbiah back from anywhere else on the phone when Volume Up is
 * held for 12 seconds. (The other direction — leaving Labbiah — is the
 * case Home key + Volume Up combo, see [HomeVolumeCombo], which needs no
 * accessibility access because Labbiah is on screen at the time.)
 *
 * Home and Power can't be intercepted by any app on stock, unrooted
 * Android — the system consumes those key events before any app ever sees
 * them. Volume keys are the one exception: an AccessibilityService that
 * requests `canRequestFilterKeyEvents` is allowed to see them globally,
 * which is exactly the mechanism real hardware-remap apps (e.g. "Button
 * Mapper") use. That's what this service relies on — a documented, public
 * Android API, not a hack, and it requires no root.
 *
 * Every individual Volume Up press/repeat is still let through untouched
 * (`onKeyEvent` always returns false), so the volume itself keeps behaving
 * completely normally — this only adds a side effect to a 12-second hold,
 * it never removes the existing one.
 *
 * Verified on-device: a held-down key generates one ACTION_DOWN followed
 * eventually by one ACTION_UP; a short tap generates both within a few
 * hundred milliseconds. The timer armed on ACTION_DOWN is cancelled on
 * ACTION_UP, so only a genuine, uninterrupted 12-second hold ever fires.
 *
 * Requires the user (or a caregiver) to turn this service on once, under
 * Settings > Accessibility — Android does not allow any app to grant
 * itself that access silently. [MainActivity] exposes a way to jump
 * straight to that settings screen (long-press and release the case's
 * Home key).
 *
 * It has a second job, unrelated to Volume Up: while a phone call is
 * ringing or in progress and the dialer's call screen is covering Labbiah,
 * it draws [CallCaseOverlay] so the case's Hang-up and Call buttons still
 * end and answer the call. An accessibility service is the one component
 * Android keeps running in the background and lets draw over other apps
 * without a separate permission.
 */
class QuickSwitchAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    private val callOverlay by lazy { CallCaseOverlay(this) }
    private var watchingCalls = false
    private var wasInCall = false
    private var telephonyCallback: Any? = null

    @Suppress("DEPRECATION")
    private var phoneStateListener: PhoneStateListener? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        AppForegroundTracker.onChange = ::updateCallOverlay
        watchCalls()
        // Declaring canRequestFilterKeyEvents in the XML config is what lets
        // the system show this capability during setup; the flag below is
        // what actually turns key-event delivery on at runtime.
        serviceInfo = serviceInfo?.apply {
            flags = flags or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used — this service only cares about the Volume Up hold.
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        instance = null
        AppForegroundTracker.onChange = null
        stopWatchingCalls()
        callOverlay.hide()
        super.onDestroy()
    }

    /**
     * Starts listening for calls starting and ending. Needs the phone
     * permissions, which may only be granted after this service is already
     * running — [MainActivity] calls this again once they are.
     */
    fun watchCalls() {
        if (watchingCalls || !CallControl.hasPermissions(this)) return
        val telephony = getSystemService(TelephonyManager::class.java) ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val callback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) = updateCallOverlay()
                }
                telephony.registerTelephonyCallback(mainExecutor, callback)
                telephonyCallback = callback
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) =
                        updateCallOverlay()
                }
                @Suppress("DEPRECATION")
                telephony.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                phoneStateListener = listener
            }
            watchingCalls = true
        } catch (_: SecurityException) {
            return
        }
        updateCallOverlay()
    }

    private fun stopWatchingCalls() {
        if (!watchingCalls) return
        watchingCalls = false
        val telephony = getSystemService(TelephonyManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (telephonyCallback as? TelephonyCallback)?.let {
                telephony.unregisterTelephonyCallback(it)
            }
            telephonyCallback = null
        } else {
            @Suppress("DEPRECATION")
            telephony.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
            phoneStateListener = null
        }
    }

    /** The overlay stands in for Labbiah's own button bar, so it is only
     * up while there is a call *and* Labbiah's bar isn't on screen. */
    private fun updateCallOverlay() {
        val inCall = CallControl.callState(this) != TelephonyManager.CALL_STATE_IDLE
        // A call the phone's own dialer handled has just ended: wherever
        // that left the screen, go back to Labbiah's home. (When Labbiah
        // is the Phone app, LabbiahInCallService does this itself.)
        if (wasInCall && !inCall && !DefaultDialer.isDefault(this)) {
            QuickSwitchActions.bringLabbiahToFront(this, vibrate = false)
            CallCenter.notifyEnded()
        }
        wasInCall = inCall
        if (inCall && !AppForegroundTracker.isLabbiahForeground) {
            callOverlay.show()
        } else {
            callOverlay.hide()
        }
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_UP) return false

        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                // Auto-repeat re-fires ACTION_DOWN many times while the key
                // stays physically held; only arm the timer on the first one
                // so the hold is timed from the initial press.
                if (pending == null) {
                    val runnable = Runnable { toggle() }
                    pending = runnable
                    handler.postDelayed(runnable, HOLD_MILLIS)
                }
            }
            KeyEvent.ACTION_UP -> {
                pending?.let { handler.removeCallbacks(it) }
                pending = null
            }
        }
        // Never consume the event — volume keeps changing normally either way.
        return false
    }

    private fun toggle() {
        pending = null
        // Leaving Labbiah is the Home + Volume Up combo's job (see
        // HomeVolumeCombo); this hold only ever brings Labbiah back.
        if (!AppForegroundTracker.isLabbiahForeground) {
            QuickSwitchActions.bringLabbiahToFront(this)
        }
    }

    companion object {
        /** The running service, if the user has turned it on. */
        @Volatile
        var instance: QuickSwitchAccessibilityService? = null
            private set

        private const val HOLD_MILLIS = 12_000L
    }
}
