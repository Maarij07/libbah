package com.labbiah.labbiah

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.Call
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import android.telephony.TelephonyManager

/**
 * Answers and ends phone calls on behalf of the case's Call and Hang-up
 * keys, while the phone's own dialer keeps handling the call itself.
 *
 * Shared by both places those keys exist: Labbiah's own button bar (via
 * [MainActivity], e.g. a call ringing as a banner over Labbiah) and
 * [CallCaseOverlay], which stands in for the bar while the dialer's call
 * screen covers Labbiah.
 *
 * When Labbiah is the default Phone app it holds the call itself (see
 * [CallCenter]) and acts on it directly. Otherwise it falls back to the
 * public [TelecomManager] API, which works for any app holding
 * `ANSWER_PHONE_CALLS`.
 */
object CallControl {

    val permissions = arrayOf(
        Manifest.permission.CALL_PHONE,
        Manifest.permission.ANSWER_PHONE_CALLS,
        Manifest.permission.READ_PHONE_STATE,
    )

    /** Asked for alongside [permissions], but only the Missed Calls
     * screen needs them — answering and ending calls works without. */
    val historyPermissions = arrayOf(
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.READ_CONTACTS,
    )

    fun hasCallLogAccess(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CALL_LOG) ==
            PackageManager.PERMISSION_GRANTED

    fun hasPermissions(context: Context): Boolean = permissions.all {
        context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    /** One of [TelephonyManager]'s `CALL_STATE_*` values. */
    fun callState(context: Context): Int {
        if (!hasPermissions(context)) return TelephonyManager.CALL_STATE_IDLE
        val telephony = context.getSystemService(TelephonyManager::class.java)
            ?: return TelephonyManager.CALL_STATE_IDLE
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephony.callStateForSubscription
            } else {
                @Suppress("DEPRECATION")
                telephony.callState
            }
        } catch (_: SecurityException) {
            TelephonyManager.CALL_STATE_IDLE
        }
    }

    /** Picks up an incoming call. Returns false if nothing is ringing. */
    fun answerIfRinging(context: Context): Boolean {
        CallCenter.ringing?.let {
            it.answer(VideoProfile.STATE_AUDIO_ONLY)
            return true
        }
        if (callState(context) != TelephonyManager.CALL_STATE_RINGING) return false
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return false
        return try {
            @Suppress("DEPRECATION")
            telecom.acceptRingingCall()
            true
        } catch (_: SecurityException) {
            false
        }
    }

    /**
     * Ends the current call — or rejects it, if it is still ringing.
     * Returns false if there is no call (or the phone is too old to let
     * another app end one: that needs Android 9).
     */
    fun endIfInCall(context: Context): Boolean {
        CallCenter.current?.let {
            if (CallCenter.stateOf(it) == Call.STATE_RINGING) {
                it.reject(false, null)
            } else {
                it.disconnect()
            }
            return true
        }
        if (callState(context) == TelephonyManager.CALL_STATE_IDLE) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return false
        return try {
            @Suppress("DEPRECATION")
            telecom.endCall()
        } catch (_: SecurityException) {
            false
        }
    }
}
