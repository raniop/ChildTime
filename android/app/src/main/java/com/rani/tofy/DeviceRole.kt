package com.rani.tofy

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Who uses this device (ParentSettings.deviceRole on iOS) + the bound child and
 * Kid Mode. Compose state backed by SharedPreferences "tofy" so routing reacts.
 */
object DeviceRole {
    enum class Role { PARENT, CHILD }
    private lateinit var app: Context
    private val prefs get() = app.getSharedPreferences("tofy", Context.MODE_PRIVATE)

    var role by mutableStateOf<Role?>(null); private set
    var joinedChildID by mutableStateOf<String?>(null); private set
    /** Kid Mode: the parent handed THIS phone to a child (ParentDashboard "תנו ל-X לשחק כאן"). */
    var kidModeChildID by mutableStateOf<String?>(null); private set

    fun init(context: Context) {
        app = context.applicationContext
        role = prefs.getString("deviceRole", null)?.let { runCatching { Role.valueOf(it) }.getOrNull() }
        joinedChildID = prefs.getString("joinedChildID", null)
        kidModeChildID = prefs.getString("kidModeChildID", null)
    }

    fun choose(r: Role?) { role = r; prefs.edit().putString("deviceRole", r?.name).apply() }
    fun join(childID: String) { joinedChildID = childID; choose(Role.CHILD); prefs.edit().putString("joinedChildID", childID).apply() }
    fun leaveChild() { joinedChildID = null; prefs.edit().remove("joinedChildID").apply(); choose(null) }
    fun startKidMode(childID: String) { kidModeChildID = childID; prefs.edit().putString("kidModeChildID", childID).apply() }
    fun endKidMode() { kidModeChildID = null; prefs.edit().remove("kidModeChildID").apply() }
}
