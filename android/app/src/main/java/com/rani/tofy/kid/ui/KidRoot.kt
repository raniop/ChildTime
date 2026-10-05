package com.rani.tofy.kid.ui

import androidx.compose.runtime.Composable

/**
 * RolePickerView (after WelcomeIntroView on the very first launch): who uses
 * this device. Persists deviceRole ("parent"/"child") in the "tofy" prefs
 * (see [KidBinding]) before calling back.
 */
@Composable
fun RolePickerScreen(onParent: () -> Unit, onChild: () -> Unit) = RolePickerFlow(onParent, onChild)

/**
 * ChildJoinView (+ ChildAuthLoadingView): anonymous sign-in, scan the parent's
 * QR / type the code → joined the family and bound to one child. The binding
 * is persisted ("tofy" prefs: joinedChildID, deviceRole = "child") before
 * [onJoined]. [onBack] is offered only during first-time setup.
 */
@Composable
fun ChildJoinScreen(onJoined: (childID: String) -> Unit, onBack: () -> Unit) = ChildJoinFlow(onJoined, onBack)

/**
 * The whole kid experience for one bound child (WorldMapView + UnlockedView +
 * covers). On a child device a parent-removed/disconnected device re-joins in
 * place (it stays a child device — [KidBinding.state] says so). In Kid Mode the
 * screen is pinned to Tofy; [onExitKidMode] runs after the parent gate (the
 * session is unbound and the pin released first).
 */
@Composable
fun KidRoot(childID: String, kidMode: Boolean, onExitKidMode: () -> Unit) = KidRootImpl(childID, kidMode, onExitKidMode)
