package com.labbiah.labbiah

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telecom.TelecomManager

/**
 * Everything to do with Labbiah being the device's default Phone app —
 * what lets [LabbiahInCallService] replace the dialer's call screen.
 *
 * As with the Home role (see [DefaultLauncher]), no app can take this
 * silently: the user confirms it in a system dialog.
 */
object DefaultDialer {

    fun isDefault(context: Context): Boolean {
        val telecom = context.getSystemService(TelecomManager::class.java)
        return telecom?.defaultDialerPackage == context.packageName
    }

    /** The system dialog that asks to make Labbiah the Phone app, or null
     * if it already is (or this phone can't offer the choice). */
    fun requestIntent(context: Context): Intent? {
        if (isDefault(context)) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(RoleManager::class.java)
            if (roleManager == null || !roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                return null
            }
            return roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
        }
        @Suppress("DEPRECATION")
        return Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).putExtra(
            TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME,
            context.packageName,
        )
    }
}
