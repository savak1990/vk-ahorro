import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'theme.dart' as generated_theme;
import '../constants/app_typography.dart';
import '../utils/platform_utils.dart';

class AdaptiveTheme {
  static ThemeData get lightTheme {
    final ColorScheme scheme = generated_theme.MaterialTheme.lightScheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: scheme,

      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: PlatformUtils.adaptiveElevation,
        centerTitle: PlatformUtils.isIOS,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: scheme.onSurface,
        ),
        systemOverlayStyle: PlatformUtils.isIOS
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: PlatformUtils.adaptiveElevation,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
        ),
        margin: PlatformUtils.adaptivePadding,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: PlatformUtils.adaptiveElevation,
          padding: PlatformUtils.adaptivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            color: scheme.onPrimary,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: PlatformUtils.adaptivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: PlatformUtils.adaptivePadding,
          textStyle: AppTypography.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: PlatformUtils.adaptivePadding,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurface.withOpacity(0.7),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurface.withOpacity(0.6),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: PlatformUtils.adaptiveElevation,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: PlatformUtils.adaptiveElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.isIOS ? 16.0 : 8.0),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      scaffoldBackgroundColor: scheme.surface,

      visualDensity: PlatformUtils.isIOS
        ? VisualDensity.standard
        : VisualDensity.comfortable,
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme scheme = generated_theme.MaterialTheme.darkScheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: scheme,

      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: PlatformUtils.adaptiveElevation,
        centerTitle: PlatformUtils.isIOS,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: scheme.onSurface,
        ),
        systemOverlayStyle: PlatformUtils.isIOS
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: PlatformUtils.adaptiveElevation,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
        ),
        margin: PlatformUtils.adaptivePadding,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: PlatformUtils.adaptiveElevation,
          padding: PlatformUtils.adaptivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            color: scheme.onPrimary,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: PlatformUtils.adaptivePadding,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurface.withOpacity(0.7),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurface.withOpacity(0.6),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: PlatformUtils.adaptiveElevation,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: PlatformUtils.adaptiveElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlatformUtils.isIOS ? 16.0 : 8.0),
        ),
      ),

      scaffoldBackgroundColor: scheme.surface,

      visualDensity: PlatformUtils.isIOS
        ? VisualDensity.standard
        : VisualDensity.comfortable,
    );
  }

  static ThemeData getCurrentTheme({bool isDark = false}) {
    return isDark ? darkTheme : lightTheme;
  }

  static Map<String, dynamic> getPlatformSpecificStyles() {
    return {
      'elevation': PlatformUtils.adaptiveElevation,
      'borderRadius': PlatformUtils.adaptiveBorderRadius,
      'padding': PlatformUtils.adaptivePadding,
      'platform': PlatformUtils.platformName,
      'primaryColor': generated_theme.MaterialTheme.lightScheme().primary,
      'backgroundColor': generated_theme.MaterialTheme.lightScheme().surface,
    };
  }
}
