package com.rani.tofy.ui.child

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable

/** Per-child page: the report — for reading; nothing is set from here (ParentDashboardView detail + ChildReportView.swift). */
@Composable
fun ChildDetailScreen(childID: String, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    ChildDetailContent(childID, onBack)
}

/** ChildSettingsView: every per-child setting + delete. */
@Composable
fun ChildSettingsScreen(childID: String, onBack: () -> Unit, onDeleted: () -> Unit, startOnScreenTime: Boolean = false,
                        startOnProfile: Boolean = false, onConnect: (() -> Unit)? = null, onLocation: (() -> Unit)? = null,
                        /** 🧪 Debug screenshots: "devices" | "difficulty" | "more" opens that page. */
                        demoPage: String? = null) {
    ChildSettingsContent(childID, onBack, onDeleted, startOnScreenTime, startOnProfile, onConnect, onLocation, demoPage)
}
