package com.labbiah.labbiah

import android.app.Activity
import android.app.AlertDialog
import android.app.role.RoleManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings

/**
 * Everything to do with Labbiah being the device's default Home app.
 *
 * Once Labbiah holds that role, Android itself launches it after every
 * reboot and on every Home press — no boot receiver or other trick needed.
 * No app can take the role silently, though: the user has to confirm it,
 * either in the system's role dialog (Android 10+) or in Settings.
 */
object DefaultLauncher {

    fun isDefault(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                return roleManager.isRoleHeld(RoleManager.ROLE_HOME)
            }
        }
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = context.packageManager
            .resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
        return resolved?.activityInfo?.packageName == context.packageName
    }

    /** Explains why, then hands off to the system to actually switch. */
    fun showPrompt(activity: Activity) {
        AlertDialog.Builder(activity, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
            .setTitle(R.string.default_launcher_title)
            .setMessage(R.string.default_launcher_message)
            .setPositiveButton(R.string.default_launcher_accept) { _, _ -> request(activity) }
            .setNegativeButton(R.string.default_launcher_decline, null)
            .show()
    }

    private fun request(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                // Android silently stops showing this dialog once the user
                // has declined it a couple of times, so only try it once per
                // run — after that, "Set as default" goes to Settings.
                if (!roleDialogShown) {
                    roleDialogShown = true
                    activity.startActivityForResult(
                        roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME),
                        REQUEST_CODE,
                    )
                    return
                }
            }
        }
        openHomeSettings(activity)
    }

    /** Heavily customised ROMs don't always expose every one of these
     * screens, so try the most specific first and fall back from there. */
    private fun openHomeSettings(activity: Activity) {
        val candidates = listOf(
            Settings.ACTION_HOME_SETTINGS,
            Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS,
            Settings.ACTION_SETTINGS,
        )
        for (action in candidates) {
            try {
                activity.startActivity(Intent(action))
                return
            } catch (_: ActivityNotFoundException) {
                // Try the next, more general screen.
            }
        }
    }

    /**
     * The launcher Labbiah replaced (e.g. Samsung One UI Home), so Quick
     * Switch can still reach it once Labbiah is the default Home app —
     * a plain CATEGORY_HOME intent would just land back on Labbiah.
     */
    fun otherLauncher(context: Context): ComponentName? {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return context.packageManager
            .queryIntentActivities(home, 0)
            .map { it.activityInfo }
            .firstOrNull {
                it.packageName != context.packageName &&
                    // Skip the "Android is starting…" placeholder shown at boot.
                    it.packageName != "com.android.settings"
            }
            ?.let { ComponentName(it.packageName, it.name) }
    }

    private var roleDialogShown = false

    private const val REQUEST_CODE = 4210
}
