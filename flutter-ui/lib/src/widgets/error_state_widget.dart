import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/platform_utils.dart';

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryText;
  final IconData? icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: Padding(
        padding: _getPlatformSpecificPadding(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? _getPlatformSpecificIcon(),
              size: _getPlatformSpecificIconSize(),
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: _getPlatformSpecificTextStyle(textTheme, colorScheme),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              _buildPlatformSpecificButton(context, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getPlatformSpecificIcon() {
    if (PlatformUtils.isIOS) {
      return CupertinoIcons.exclamationmark_triangle;
    } else if (PlatformUtils.isAndroid) {
      return Icons.error_outline;
    } else {
      return Icons.error_outline;
    }
  }

  double _getPlatformSpecificIconSize() {
    if (PlatformUtils.isIOS) {
      return 48.0;
    } else if (PlatformUtils.isAndroid) {
      return 48.0;
    } else {
      return 48.0;
    }
  }

  TextStyle _getPlatformSpecificTextStyle(TextTheme textTheme, ColorScheme colorScheme) {
    if (PlatformUtils.isIOS) {
      return textTheme.bodyLarge?.copyWith(
        color: colorScheme.error,
        fontSize: 16,
      ) ?? const TextStyle();
    } else if (PlatformUtils.isAndroid) {
      return textTheme.bodyLarge?.copyWith(
        color: colorScheme.error,
      ) ?? const TextStyle();
    } else {
      return textTheme.bodyLarge?.copyWith(
        color: colorScheme.error,
      ) ?? const TextStyle();
    }
  }

  Widget _buildPlatformSpecificButton(BuildContext context, ColorScheme colorScheme) {
    final buttonText = retryText ?? 'Retry';

    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        onPressed: onRetry,
        child: Text(buttonText),
      );
    } else if (PlatformUtils.isAndroid) {
      return ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        child: Text(buttonText),
      );
    } else {
      return ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        child: Text(buttonText),
      );
    }
  }

  EdgeInsetsGeometry _getPlatformSpecificPadding() {
    if (PlatformUtils.isIOS) {
      return const EdgeInsets.all(24.0);
    } else if (PlatformUtils.isAndroid) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }
} 