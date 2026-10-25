package com.labbiah.labbiah

/**
 * Tracks whether Labbiah's own activity is the one currently on screen.
 *
 * [QuickSwitchAccessibilityService] and [MainActivity] run in the same app
 * process, so a plain in-memory flag is enough to share this — no IPC
 * needed. [MainActivity] flips it in onResume/onPause; the service reads
 * it when the Volume-Up hold fires, to decide which direction to toggle,
 * and listens via [onChange] to know when its call-screen button bar is
 * needed (Labbiah's own bar is covered) and when it isn't.
 */
object AppForegroundTracker {
    @Volatile
    var isLabbiahForeground: Boolean = false
        set(value) {
            field = value
            onChange?.invoke()
        }

    /** Called on the main thread whenever [isLabbiahForeground] is set. */
    var onChange: (() -> Unit)? = null
}
