import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformUtils {
  // Platform detection
  static bool get isWeb => kIsWeb;
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWeb;

  // Additional utilities for adaptive navigation
  static bool get shouldUseSideNavigation => isWeb;
  static bool get shouldUseBottomNavigation => isMobile;

  // Screen size detection for web
  static bool get isWideScreen {
    if (!isWeb) return false;
    // For web, check screen width via MediaQuery
    return true; // Will be determined in the widget
  }

  // Methods for platform-specific styles
  static double get adaptiveElevation {
    if (isIOS) return 0.0; // iOS does not use shadows
    if (isAndroid) return 6.0; // Android uses Material Design shadows
    return 2.0; // Web uses medium shadows
  }

  static double get adaptiveBorderRadius {
    if (isIOS) return 8.0; // iOS uses softer corners
    if (isAndroid) return 4.0; // Android uses Material Design corners
    return 6.0; // Web uses medium corners
  }

  static EdgeInsets get adaptivePadding {
    if (isIOS) return const EdgeInsets.all(16.0);
    if (isAndroid) return const EdgeInsets.all(12.0);
    return const EdgeInsets.all(14.0);
  }

  // Methods for determining system settings
  static bool get isDarkModeSupported {
    // iOS and Android support dark theme
    return isMobile;
  }

  static String get platformName {
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  // Methods for adaptive styles
  static Map<String, dynamic> get adaptiveStyles {
    return {
      'elevation': adaptiveElevation,
      'borderRadius': adaptiveBorderRadius,
      'padding': adaptivePadding,
      'platform': platformName,
    };
  }
}
