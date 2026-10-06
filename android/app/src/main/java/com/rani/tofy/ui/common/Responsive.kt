package com.rani.tofy.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Tablets. A phone layout stretched across 1280dp turns every button into a
 * banner and every card into a letterbox, so forms and lists stay in a column
 * of readable width and sit centred on the backdrop (iOS does the same with
 * `.frame(maxWidth: 600)` on the sign-in and onboarding screens).
 *
 * Grids are the exception — a world grid or a child grid should use the room —
 * so they ask [wideLayout] for a column count instead.
 */
@Composable
fun isWideScreen(): Boolean = LocalConfiguration.current.screenWidthDp >= 600

/** Columns for a grid that may breathe on a tablet. */
@Composable
fun gridColumns(phone: Int = 2, tablet: Int = 3): Int = if (isWideScreen()) tablet else phone

/** Cap a form/list column at a readable width (no-op on a phone). */
fun Modifier.contentColumn(max: Dp = 600.dp): Modifier = this.widthIn(max = max)

/** Full-bleed container whose content is a centred, width-capped column. */
@Composable
fun CenteredContent(max: Dp = 600.dp, content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Box(Modifier.fillMaxWidth().contentColumn(max), content = content)
    }
}
