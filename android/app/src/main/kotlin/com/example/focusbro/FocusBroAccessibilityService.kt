package com.example.focusbro

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class FocusBroAccessibilityService : AccessibilityService() {
    private var lastBlockedPackage: String? = null
    private var lastBlockTimeMs: Long = 0

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return

        val eventType = event.eventType
        if (
            eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_LAST_FOREGROUND_PACKAGE, packageName).apply()

        if (!prefs.getBoolean(KEY_ENABLED, false)) return

        val blockedPackages =
            prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
        if (!blockedPackages.contains(packageName)) return

        val now = System.currentTimeMillis()
        if (lastBlockedPackage == packageName && now - lastBlockTimeMs < 1500) {
            return
        }

        lastBlockedPackage = packageName
        lastBlockTimeMs = now

        Toast.makeText(
            this,
            "Blocked by FocusBro during focus mode",
            Toast.LENGTH_SHORT
        ).show()
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    override fun onInterrupt() = Unit

    companion object {
        const val PREFS_NAME = "focusbro_app_blocking"
        const val KEY_ENABLED = "enabled"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_SHOW_OVERLAY = "show_overlay"
        const val KEY_LAST_FOREGROUND_PACKAGE = "last_foreground_package"
    }
}
