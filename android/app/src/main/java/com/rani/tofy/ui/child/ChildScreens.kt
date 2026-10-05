package com.rani.tofy.ui.child

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable

/** Per-child page: report + devices + entry to settings (ParentDashboardView detail + ChildReportView.swift). */
@Composable
fun ChildDetailScreen(childID: String, onBack: () -> Unit, onSettings: () -> Unit, onActions: () -> Unit, onConnectDevice: () -> Unit) {
    BackHandler(onBack = onBack)
    ChildDetailContent(childID, onBack, onSettings, onActions, onConnectDevice)
}

/** ChildSettingsView: every per-child setting + delete. */
@Composable
fun ChildSettingsScreen(childID: String, onBack: () -> Unit, onDeleted: () -> Unit) {
    ChildSettingsContent(childID, onBack, onDeleted)
}
