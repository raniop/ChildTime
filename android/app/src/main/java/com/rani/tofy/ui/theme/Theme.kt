package com.rani.tofy.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.LayoutDirection
import com.rani.tofy.i18n.I18n

private val scheme = darkColorScheme(
    primary = Ink.gold2, onPrimary = Ink.deep,
    secondary = Color.White, onSecondary = Ink.indigo,
    background = Color(0xFF5E60CE), onBackground = Color.White,
    surface = Ink.sheet, onSurface = Color.White,
    surfaceContainer = Ink.sheet, surfaceContainerHigh = Ink.sheet, surfaceContainerLow = Ink.sheet,
    onSurfaceVariant = Ink.secondary, outline = Color.White.copy(alpha = 0.35f),
    error = Ink.weak,
)

@Composable
fun TofyTheme(content: @Composable () -> Unit) {
    val base = Typography()
    fun TextStyle.r() = copy(fontFamily = Rounded)
    val type = Typography(
        displayLarge = base.displayLarge.r(), displayMedium = base.displayMedium.r(), displaySmall = base.displaySmall.r(),
        headlineLarge = base.headlineLarge.r(), headlineMedium = base.headlineMedium.r(), headlineSmall = base.headlineSmall.r(),
        titleLarge = base.titleLarge.r(), titleMedium = base.titleMedium.r(), titleSmall = base.titleSmall.r(),
        bodyLarge = base.bodyLarge.r(), bodyMedium = base.bodyMedium.r(), bodySmall = base.bodySmall.r(),
        labelLarge = base.labelLarge.r(), labelMedium = base.labelMedium.r(), labelSmall = base.labelSmall.r(),
    )
    val dir = if (I18n.language.rtl) LayoutDirection.Rtl else LayoutDirection.Ltr
    CompositionLocalProvider(LocalLayoutDirection provides dir) {
        MaterialTheme(colorScheme = scheme, typography = type, content = content)
    }
}
