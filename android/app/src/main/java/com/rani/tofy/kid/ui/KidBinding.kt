package com.rani.tofy.kid.ui

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * The device's role and child binding — iOS ParentSettings.deviceRole /
 * joinedChildID / justDisconnected / hasSeenWelcome, kept in the shared
 * "tofy" prefs so the app's root navigation can read them too.
 *
 *   deviceRole       "PARENT" | "CHILD" | absent (unset) — the SAME stored values as
 *                    com.rani.tofy.DeviceRole (enum names), which owns routing
 *   joinedChildID    the ONE child this device plays as (child devices only)
 *   justDisconnected the parent removed this device (or it was disconnected
 *                    from the gear): it stays a CHILD device and shows the
 *                    "scan again" screen — never the role picker (iOS
 *                    resetAsRemovedDevice: a removed kid device must not be
 *                    able to silently become a parent device).
 *
 * Observe [state] to route: role child + joinedChildID → KidRoot; role child
 * without a binding → ChildJoinScreen; role unset → RolePickerScreen.
 */
object KidBinding {
    data class State(
        /** "parent" | "child" | "unset" (normalized from the stored enum name). */
        val deviceRole: String = "unset",
        val joinedChildID: String? = null,
        val justDisconnected: Boolean = false,
        val hasSeenWelcome: Boolean = false,
    )

    private var prefs: SharedPreferences? = null
    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state

    fun init(context: Context) {
        if (prefs != null) return
        prefs = context.applicationContext.getSharedPreferences("tofy", Context.MODE_PRIVATE)
        reload()
    }

    private fun reload() {
        val p = prefs ?: return
        _state.value = State(
            deviceRole = p.getString("deviceRole", null)?.lowercase() ?: "unset",
            joinedChildID = p.getString("joinedChildID", null),
            justDisconnected = p.getBoolean("justDisconnected", false),
            hasSeenWelcome = p.getBoolean("hasSeenWelcome", false),
        )
    }

    /** "parent" / "child" / "unset" → stored as DeviceRole.Role names (PARENT/CHILD) or removed. */
    fun setRole(role: String) {
        val e = prefs?.edit() ?: return
        if (role == "parent" || role == "child") e.putString("deviceRole", role.uppercase()) else e.remove("deviceRole")
        e.apply(); reload()
    }

    fun markWelcomeSeen() { prefs?.edit()?.putBoolean("hasSeenWelcome", true)?.apply(); reload() }

    /** Bound to a child (a successful join): a child device, reconnected. */
    fun bind(childID: String) {
        prefs?.edit()?.putString("joinedChildID", childID)?.putString("deviceRole", "CHILD")
            ?.putBoolean("justDisconnected", false)?.apply()
        reload()
    }

    /** HouseholdManager.resetAsRemovedDevice — drop the binding, stay a child device. */
    fun disconnected() {
        prefs?.edit()?.remove("joinedChildID")?.putString("deviceRole", "CHILD")
            ?.putBoolean("justDisconnected", true)?.apply()
        reload()
    }
}
