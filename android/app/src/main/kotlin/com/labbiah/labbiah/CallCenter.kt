package com.labbiah.labbiah

import android.content.Context
import android.telecom.Call

/**
 * The calls Android has handed to Labbiah as the default Phone app (see
 * [LabbiahInCallService]), and the bridge that tells Flutter about them so
 * it can draw the call screen.
 *
 * [LabbiahInCallService] and [MainActivity] run in the same process, so a
 * plain in-memory object is enough to share this.
 */
object CallCenter {

    private val calls = mutableListOf<Call>()

    /** Contact lookups, kept per number so a call is only looked up once. */
    private val callers = HashMap<String, ContactLookup.Match>()

    /**
     * Receives the call to show — or null once there is none, which is
     * also Flutter's cue to return to Labbiah's home screen.
     */
    private var listener: ((Map<String, Any?>?) -> Unit)? = null

    fun attachListener(callback: (Map<String, Any?>?) -> Unit) {
        listener = callback
    }

    fun detachListener(callback: (Map<String, Any?>?) -> Unit) {
        if (listener === callback) {
            listener = null
        }
    }

    /** Whether the current call is on loudspeaker. */
    var speakerOn = false

    /** The call the case's keys act on: a ringing one first, else the latest. */
    val current: Call?
        get() = ringing ?: calls.lastOrNull()

    val ringing: Call?
        get() = calls.firstOrNull { stateOf(it) == Call.STATE_RINGING }

    fun isTracking(call: Call): Boolean = call in calls

    fun add(context: Context, call: Call) {
        calls.add(call)
        notifyChanged(context)
    }

    fun remove(context: Context, call: Call) {
        calls.remove(call)
        if (calls.isEmpty()) callers.clear()
        notifyChanged(context)
    }

    fun notifyChanged(context: Context) {
        listener?.invoke(snapshot(context))
    }

    /** For calls Labbiah isn't the Phone app for: it never saw the call,
     * but still needs to go back to its home screen when one ends. */
    fun notifyEnded() {
        listener?.invoke(null)
    }

    fun snapshot(context: Context): Map<String, Any?>? {
        val call = current ?: return null
        val state = when (stateOf(call)) {
            Call.STATE_RINGING -> "ringing"
            Call.STATE_ACTIVE, Call.STATE_HOLDING -> "active"
            Call.STATE_DISCONNECTED, Call.STATE_DISCONNECTING -> return null
            else -> "dialing"
        }
        val details = call.details
        val number = details?.handle?.schemeSpecificPart.orEmpty()
        val caller = lookUp(context, number)
        return mapOf(
            "state" to state,
            "number" to number,
            "name" to (caller.name ?: details?.callerDisplayName?.takeIf { it.isNotBlank() }),
            "photo" to caller.photo,
            "speaker" to speakerOn,
            "connectedAt" to (details?.connectTimeMillis ?: 0L),
        )
    }

    fun stateOf(call: Call): Int {
        @Suppress("DEPRECATION")
        return call.state
    }

    private fun lookUp(context: Context, number: String): ContactLookup.Match =
        callers.getOrPut(number) { ContactLookup.find(context, number) }
}
