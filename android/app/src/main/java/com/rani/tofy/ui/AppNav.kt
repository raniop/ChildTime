package com.rani.tofy.ui

import androidx.compose.runtime.*
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.ui.home.HomeScreen

/** Signed in with a family: the parent app's screens. */
@Composable
fun AppNav() {
    val nav = rememberNavController()
    val state by FamilyRepository.state.collectAsState()
    NavHost(nav, startDestination = "home") {
        composable("home") {
            HomeScreen(
                state = state,
                onOpenChild = { nav.navigate("child/${it.id}") },
                onActions = { },
                onAddChild = { },
                onChores = { },
                onSettings = { },
                onBell = { },
                onConnectDevice = { },
            )
        }
        composable("child/{id}") { }
    }
}
