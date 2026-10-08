package com.rani.tofy.ui

import androidx.compose.runtime.*
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.rani.tofy.data.Child
import com.rani.tofy.data.Commands
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.ui.activity.ActivityScreen
import com.rani.tofy.ui.activity.HomeBanners
import com.rani.tofy.ui.activity.unreadActivityCount
import com.rani.tofy.ui.child.ChildDetailScreen
import com.rani.tofy.ui.child.ChildSettingsScreen
import com.rani.tofy.ui.chores.ChoresScreen
import com.rani.tofy.ui.home.ActionsSheet
import com.rani.tofy.ui.home.CommandStatusSheet
import com.rani.tofy.ui.home.HomeScreen
import com.rani.tofy.ui.onboarding.AddChildFlow
import com.rani.tofy.ui.onboarding.ConnectDeviceSheet
import com.rani.tofy.ui.onboarding.ParentPinSetupScreen
import com.rani.tofy.ui.settings.SettingsScreen

/**
 * Signed in with a family. Onboarding gates first (no parent code → set it; no
 * children → add the first child), then the parent app's screens.
 */
@Composable
fun AppNav() {
    val state by FamilyRepository.state.collectAsState()
    val hh = state.household
    if (hh == null) return
    if (hh.parentPinHash == null) { ParentPinSetupScreen(onDone = {}); return }
    // Stays in the flow after step 2 writes the child (the flag is set before the
    // save), so steps 3–4 — device + lock — still show for the first child.
    val onboarding = com.rani.tofy.ui.onboarding.rememberOnboardingActive()
    if (!state.childrenLoaded) return
    if (state.children.isEmpty() || onboarding) { AddChildFlow(firstChild = true, onDone = {}, onCancel = {}); return }

    val nav = rememberNavController()
    var actionsFor by remember { mutableStateOf<Child?>(null) }
    var connectFor by remember { mutableStateOf<String?>(null) }
    val status by Commands.status.collectAsState()

    NavHost(nav, startDestination = "home") {
        composable("home") {
            HomeScreen(
                state = state,
                onOpenChild = { nav.navigate("child/${it.id}") },
                onChildSettings = { nav.navigate("childSettings/${it.id}") },
                onActions = { actionsFor = it },
                onAddChild = { nav.navigate("addChild") },
                onChores = { nav.navigate("chores") },
                onSettings = { nav.navigate("settings") },
                onBell = { nav.navigate("activity") },
                onConnectDevice = { connectFor = it.id },
                onLocation = { c -> nav.navigate(if (c == null) "location" else "location?child=${c.id}") },
                bellBadge = unreadActivityCount(),
                sheetOpen = actionsFor != null || connectFor != null || status != null,
                banners = { HomeBanners(state, onChores = { nav.navigate("chores") },
                    onPaywall = { nav.navigate("paywall") }, onPack = { pack, cid -> nav.navigate("pack/$pack/$cid") }) },
            )
        }
        composable("child/{id}") { e ->
            val id = e.arguments?.getString("id") ?: return@composable
            ChildDetailScreen(id, onBack = { nav.popBackStack() }, onSettings = { nav.navigate("childSettings/$id") },
                onActions = { state.children.firstOrNull { it.id == id }?.let { actionsFor = it } }, onConnectDevice = { connectFor = id })
        }
        composable("childSettings/{id}") { e ->
            val id = e.arguments?.getString("id") ?: return@composable
            ChildSettingsScreen(id, onBack = { nav.popBackStack() }, onDeleted = { nav.popBackStack("home", false) })
        }
        // ⏱ Straight to the daily screen-time limit (from the child's "פעולות").
        composable("childScreenTime/{id}") { e ->
            val id = e.arguments?.getString("id") ?: return@composable
            ChildSettingsScreen(id, onBack = { nav.popBackStack() }, onDeleted = { nav.popBackStack("home", false) }, startOnScreenTime = true)
        }
        composable("addChild") { AddChildFlow(firstChild = false, onDone = { nav.popBackStack() }, onCancel = { nav.popBackStack() }) }
        composable("chores") { ChoresScreen(onBack = { nav.popBackStack() }) }
        composable("location?child={child}", arguments = listOf(androidx.navigation.navArgument("child") { nullable = true; defaultValue = null })) { e ->
            com.rani.tofy.ui.location.ParentLocationScreen(e.arguments?.getString("child")) { nav.popBackStack() }
        }
        composable("activity") { ActivityScreen(onBack = { nav.popBackStack() }) }
        composable("settings") { SettingsScreen(onBack = { nav.popBackStack() }) }
        composable("paywall") { com.rani.tofy.billing.GatedPaywall("request") { nav.popBackStack() } }
        composable("pack/{pack}/{cid}") { e ->
            com.rani.tofy.billing.PackPurchaseScreen(e.arguments?.getString("pack") ?: "", e.arguments?.getString("cid")) { nav.popBackStack() }
        }
    }

    actionsFor?.let { c ->
        ActionsSheet(c, state, onDismiss = { actionsFor = null },
            onChores = { com.rani.tofy.data.ChoresRepository.focusChildID = c.id; actionsFor = null; nav.navigate("chores") },
            onConnect = { actionsFor = null; connectFor = c.id },
            onSettings = { actionsFor = null; nav.navigate("childSettings/${c.id}") },
            onScreenTime = { actionsFor = null; nav.navigate("childScreenTime/${c.id}") },
            onLocation = { actionsFor = null; nav.navigate("location?child=${c.id}") })
    }
    connectFor?.let { ConnectDeviceSheet(it, onDismiss = { connectFor = null }) }
    // 📍 Follow the children's fixes for the cards (no push to their phones), and
    // open the map on a child when an arrival push was tapped.
    LaunchedEffect(state.children.map { it.id }) { com.rani.tofy.ui.location.LocationRepository.follow(state.children.map { it.id }) }
    val openFor by com.rani.tofy.ui.location.LocationRepository.openMapFor.collectAsState()
    LaunchedEffect(openFor) { openFor?.let { nav.navigate("location?child=$it"); com.rani.tofy.ui.location.LocationRepository.openMapFor.value = null } }
    status?.let { CommandStatusSheet(it, state, onDismiss = { Commands.clearStatus() }) }
}
