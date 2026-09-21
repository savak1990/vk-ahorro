import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformColors {
  // Определение платформы
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isWeb => kIsWeb;

  // iOS-специфичные цвета (следуют Human Interface Guidelines)
  static const Color _iosPrimary = Color(0xFF007AFF);        // iOS Blue
  static const Color _iosSecondary = Color(0xFF5856D6);      // iOS Purple
  static const Color _iosSuccess = Color(0xFF34C759);        // iOS Green
  static const Color _iosWarning = Color(0xFFFF9500);        // iOS Orange
  static const Color _iosError = Color(0xFFFF3B30);          // iOS Red
  static const Color _iosBackground = Color(0xFFF2F2F7);     // iOS Light Gray
  static const Color _iosSurface = Color(0xFFFFFFFF);        // iOS White
  static const Color _iosTextPrimary = Color(0xFF000000);    // iOS Black
  static const Color _iosTextSecondary = Color(0xFF8E8E93);  // iOS Gray

  // Android-специфичные цвета (Финансовая палитра)
  static const Color _androidPrimary = Color(0xFF1E3A8A);    // Глубокий синий - доверие
  static const Color _androidSecondary = Color(0xFFFACC15);  // Серо-синий - профессионализм
  static const Color _androidSuccess = Color(0xFF059669);    // Изумрудный зеленый - рост
  static const Color _androidWarning = Color(0xFFD97706);    // Оранжевый - внимание
  static const Color _androidError = Color(0xFFDC2626);      // Красный - убытки
  static const Color _androidBackground = Color(0xFFF8FAFC); // Очень светлый серый
  static const Color _androidSurface = Color(0xFFFFFFFF);    // Белый
  static const Color _androidTextPrimary = Color(0xFF1E293B); // Темно-серый
  static const Color _androidTextSecondary = Color(0xFF64748B); // Средне-серый

  // Универсальные цвета (одинаковые для всех платформ)
  static const Color _universalBlack = Color(0xFF000000);
  static const Color _universalWhite = Color(0xFFFFFFFF);

  // Геттеры для получения платформо-специфичных цветов
  static Color get primary => isIOS ? _iosPrimary : _androidPrimary;
  static Color get secondary => isIOS ? _iosSecondary : _androidSecondary;
  static Color get success => isIOS ? _iosSuccess : _androidSuccess;
  static Color get warning => isIOS ? _iosWarning : _androidWarning;
  static Color get error => isIOS ? _iosError : _androidError;
  static Color get background => isIOS ? _iosBackground : _androidBackground;
  static Color get surface => isIOS ? _iosSurface : _androidSurface;
  static Color get textPrimary => isIOS ? _iosTextPrimary : _androidTextPrimary;
  static Color get textSecondary => isIOS ? _iosTextSecondary : _androidTextSecondary;

  // Финансовые цвета (адаптированные под платформу)
  static Color get income => isIOS ? _iosSuccess : _androidSuccess;
  static Color get expense => isIOS ? _iosError : _androidError;
  static Color get neutral => isIOS ? _iosTextSecondary : _androidTextSecondary;
  
  // Дополнительные финансовые цвета
  static Color get profit => income;                    // Прибыль (зеленый)
  static Color get loss => expense;                     // Убыток (красный)
  static Color get balance => _iosPrimary;              // Баланс (синий)
  static Color get investment => _iosSecondary;         // Инвестиции (серо-синий)
  static Color get savings => _iosSuccess;              // Сбережения (зеленый)
  static Color get debt => _iosError;                   // Долг (красный)
  static Color get budget => _iosWarning;               // Бюджет (оранжевый)

  // Цвета для состояний
  static Color get disabled => isIOS ? _iosTextSecondary : _androidTextSecondary;
  static Color get selected => isIOS ? _iosPrimary.withValues(alpha: 0.1) : _androidPrimary.withValues(alpha: 0.1);
  static Color get hover => isIOS ? _iosBackground : _androidBackground;

  // Цвета для границ и разделителей
  static Color get border => isIOS ? _iosTextSecondary.withValues(alpha: 0.3) : _androidTextSecondary.withValues(alpha: 0.3);
  static Color get divider => isIOS ? _iosTextSecondary.withValues(alpha: 0.2) : _androidTextSecondary.withValues(alpha: 0.2);

  // Цвета для карточек
  static Color get cardBackground => surface;
  static Color get cardShadow => _universalBlack.withValues(alpha: 0.1);

  // Темная тема (адаптированная под платформу)
  static Color get darkPrimary => isIOS ? _iosPrimary : _androidPrimary;
  static Color get darkBackground => _universalBlack;
  static Color get darkSurface => const Color(0xFF1C1C1E); // iOS Dark Gray
  static Color get darkTextPrimary => _universalWhite;
  static Color get darkTextSecondary => isIOS ? const Color(0xFF8E8E93) : const Color(0xFFBDBDBD);

  // Метод для получения цвета с учетом платформы и темы
  static Color getColor({
    required Color lightColor,
    Color? darkColor,
    Color? iosColor,
    Color? androidColor,
  }) {
    // Приоритет: платформо-специфичный цвет > универсальный цвет
    if (isIOS && iosColor != null) return iosColor;
    if (isAndroid && androidColor != null) return androidColor;
    
    return lightColor;
  }

  // Метод для получения цвета с учетом темной темы
  static Color getThemeColor({
    required Color lightColor,
    required Color darkColor,
  }) {
    // Здесь можно добавить логику определения текущей темы
    // Пока возвращаем светлый цвет
    return lightColor;
  }
} 