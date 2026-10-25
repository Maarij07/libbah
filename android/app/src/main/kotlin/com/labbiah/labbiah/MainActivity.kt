package com.labbiah.labbiah

import android.app.AlertDialog
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telecom.Call
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.labbiah.labbiah/quick_switch"
    private val defaultLauncherChannelName = "com.labbiah.labbiah/default_launcher"
    private val callControlChannelName = "com.labbiah.labbiah/call_control"
    private var callListener: ((Map<String, Any?>?) -> Unit)? = null
    private var lastHadCall = false
    private var quickSwitchPromptRequested = false
    private var quickSwitchPromptShown = false
    private val homeVolumeCombo by lazy { HomeVolumeCombo(this) }

    // Handling calls has to be set up before one arrives — an incoming
    // call can't stop to ask. Being the default Phone app is what lets
    // Labbiah show its own call screen; the phone permissions alone still
    // let the case's keys answer and end calls on the dialer's screen.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        updateLockScreenAccess()
        if (savedInstanceState != null) return
        val dialerRequest = DefaultDialer.requestIntent(this)
        if (dialerRequest != null) {
            startActivityForResult(dialerRequest, DIALER_ROLE_REQUEST)
        } else {
            requestPhonePermissions()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DIALER_ROLE_REQUEST) requestPhonePermissions()
    }

    private fun requestPhonePermissions() {
        val missing = (CallControl.permissions + CallControl.historyPermissions).filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            QuickSwitchAccessibilityService.instance?.watchCalls()
        } else {
            requestPermissions(missing.toTypedArray(), PHONE_PERMISSIONS_REQUEST)
        }
    }

    // Read off the main thread: it is a database query plus a contact
    // lookup per caller.
    private fun loadMissedCalls(result: MethodChannel.Result) {
        if (!CallControl.hasCallLogAccess(this)) {
            requestPermissions(CallControl.historyPermissions, PHONE_PERMISSIONS_REQUEST)
            result.error("denied", "Call history access has not been granted", null)
            return
        }
        Thread {
            val missed = try {
                MissedCalls.query(applicationContext)
            } catch (_: SecurityException) {
                null
            }
            runOnUiThread {
                if (missed != null) {
                    result.success(missed)
                } else {
                    result.error("denied", "Call history access has not been granted", null)
                }
            }
        }.start()
    }

    // A call has to be visible, and answerable, on a locked or sleeping
    // phone — but only a call: the rest of Labbiah stays behind the lock.
    private fun updateLockScreenAccess() {
        val inCall = CallCenter.current != null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(inCall)
            setTurnScreenOn(inCall)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (inCall) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        updateLockScreenAccess()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PHONE_PERMISSIONS_REQUEST) {
            QuickSwitchAccessibilityService.instance?.watchCalls()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val quickSwitchChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        homeVolumeCombo.onVolumeUpChanged = { held ->
            quickSwitchChannel.invokeMethod("volumeUpChanged", held)
        }
        quickSwitchChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "promptIfNeeded" -> {
                        quickSwitchPromptRequested = true
                        maybePromptQuickSwitch()
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        showAccessibilityDisclosure()
                        result.success(null)
                    }
                    "setHomeHeld" -> {
                        homeVolumeCombo.setHomeHeld(call.arguments as Boolean)
                        result.success(homeVolumeCombo.volumeUpDuringHomeHold)
                    }
                    else -> result.notImplemented()
                }
            }
        val callChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callControlChannelName)
        val listener: (Map<String, Any?>?) -> Unit = { call ->
            lastHadCall = call != null
            updateLockScreenAccess()
            callChannel.invokeMethod("callChanged", call)
        }
        callListener = listener
        CallCenter.attachListener(listener)
        callChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentCall" -> {
                        result.success(CallCenter.snapshot(this))
                    }
                    "missedCalls" -> loadMissedCalls(result)
                    "answerIfRinging" -> result.success(CallControl.answerIfRinging(this))
                    "endIfInCall" -> result.success(CallControl.endIfInCall(this))
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, defaultLauncherChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDefault" -> result.success(DefaultLauncher.isDefault(this))
                    "showPrompt" -> {
                        DefaultLauncher.showPrompt(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callListener?.let { CallCenter.detachListener(it) }
        callListener = null
        homeVolumeCombo.onVolumeUpChanged = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // Google Play requires a prominent disclosure, accepted by the user,
    // before sending them to enable an AccessibilityService.
    private fun showAccessibilityDisclosure() {
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
            .setTitle(R.string.quick_switch_disclosure_title)
            .setMessage(R.string.quick_switch_disclosure_message)
            .setPositiveButton(R.string.quick_switch_disclosure_accept) { _, _ ->
                startActivity(
                    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                )
            }
            .setNegativeButton(R.string.quick_switch_disclosure_decline, null)
            .show()
    }

    // Labbiah is the Home screen: nothing — Android's Back included — may
    // close it. Returning true tells Flutter the "exit the app" request has
    // been dealt with, so the activity is never finished from under the
    // person. The Flutter side blocks Back too (PopScope in PhoneShell).
    override fun popSystemNavigator(): Boolean = true

    // Observes Volume Up for the Home + Volume Up combo without consuming
    // it, so the volume itself still changes normally.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> homeVolumeCombo.setVolumeUpHeld(true)
                KeyEvent.ACTION_UP -> homeVolumeCombo.setVolumeUpHeld(false)
            }
        }
        if (handleCallVolumeKey(event)) return true
        return super.dispatchKeyEvent(event)
    }

    // During a call on Labbiah's own call screen, the volume buttons pick
    // where the sound comes out instead of changing the volume: Up for the
    // loudspeaker, Down for the earpiece. Not while it is still ringing —
    // there they keep their usual job of silencing the ringtone.
    private fun handleCallVolumeKey(event: KeyEvent): Boolean {
        val up = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP
        if (!up && event.keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) return false
        val call = CallCenter.current ?: return false
        if (CallCenter.stateOf(call) == Call.STATE_RINGING) return false
        val service = LabbiahInCallService.instance ?: return false
        // A held button auto-repeats; only the press itself counts.
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            service.setSpeaker(up)
        }
        return true
    }

    // Shared with QuickSwitchAccessibilityService (same process) so its
    // Volume-Up hold only fires while Labbiah is *not* on screen.
    override fun onResume() {
        super.onResume()
        callListener?.let {
            CallCenter.attachListener(it)
            if (CallCenter.current != null || lastHadCall) {
                CallCenter.notifyChanged(this)
            }
        }
        AppForegroundTracker.isLabbiahForeground = true
    }

    override fun onPause() {
        AppForegroundTracker.isLabbiahForeground = false
        super.onPause()
    }

    // Once another window (a dialog, the notification shade, another app)
    // has focus, Volume Up's key-up goes there instead of here — so forget
    // any held state rather than leave Volume Up stuck "down" and let a
    // later Home hold alone fire the combo.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) homeVolumeCombo.reset()
        if (hasFocus) maybePromptQuickSwitch()
    }

    private fun quickSwitchAccessibilityEnabled(): Boolean {
        val target = ComponentName(this, QuickSwitchAccessibilityService::class.java)
        return Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            .orEmpty().split(':').any { ComponentName.unflattenFromString(it) == target }
    }

    private fun maybePromptQuickSwitch() {
        if (!quickSwitchPromptRequested || quickSwitchPromptShown || !hasWindowFocus() ||
            isFinishing || isDestroyed || CallCenter.current != null) return
        quickSwitchPromptShown = true
        if (!quickSwitchAccessibilityEnabled()) {
            showAccessibilityDisclosure()
        }
    }

    companion object {
        private const val PHONE_PERMISSIONS_REQUEST = 4211
        private const val DIALER_ROLE_REQUEST = 4212
    }
}
