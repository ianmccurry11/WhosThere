package com.whosthere.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = AppPrimary,
    onPrimary = Color.White,
    primaryContainer = AppLightBlue,
    onPrimaryContainer = AppNavy,
    secondary = AppSecondary,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFFFF3E0),
    onSecondaryContainer = Color(0xFF5D3F1A),
    tertiary = AppAccent,
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFE0D6),
    onTertiaryContainer = Color(0xFF5C1A0B),
    error = Color(0xFFB3261E),
    onError = Color.White,
    errorContainer = Color(0xFFF9DEDC),
    onErrorContainer = Color(0xFF410E0B),
    background = AppBackground,
    onBackground = AppNavy,
    surface = Color.White,
    onSurface = AppNavy,
    surfaceVariant = Color(0xFFF0F4F8),
    onSurfaceVariant = Color(0xFF44474F),
    outline = Color(0xFF74777F),
    outlineVariant = Color(0xFFC4C6D0)
)

@Composable
fun WhosThereTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = AppTypography,
        content = content
    )
}
