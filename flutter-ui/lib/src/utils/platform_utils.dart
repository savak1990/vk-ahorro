import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformUtils {

  static bool get isWeb => kIsWeb;
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWeb;

  static bool get shouldUseSideNavigation => isWeb;
  static bool get shouldUseBottomNavigation => isMobile;

  static bool get isWideScreen {
    if (!isWeb) return false;

    return true;
  }

  static double get adaptiveElevation {
    if (isIOS) return 0.0;
    if (isAndroid) return 6.0;
    return 2.0;
  }

  static double get adaptiveBorderRadius {
    if (isIOS) return 8.0;
    if (isAndroid) return 4.0;
    return 6.0;
  }

  static EdgeInsets get adaptivePadding {
    if (isIOS) return const EdgeInsets.all(16.0);
    if (isAndroid) return const EdgeInsets.all(12.0);
    return const EdgeInsets.all(14.0);
  }

  static bool get isDarkModeSupported {

    return isMobile;
  }

  static String get platformName {
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  static Map<String, dynamic> get adaptiveStyles {
    return {
      'elevation': adaptiveElevation,
      'borderRadius': adaptiveBorderRadius,
      'padding': adaptivePadding,
      'platform': platformName,
    };
  }
}
