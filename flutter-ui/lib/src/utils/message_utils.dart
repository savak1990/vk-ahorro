import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'platform_utils.dart';

class MessageUtils {
  /// Shows a platform-appropriate message (snackbar on Android, alert on iOS)
  /// Returns true if message was shown successfully, false otherwise
  static Future<bool> showMessage(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    String? title,
  }) async {
    // Check if context is still mounted and valid
    if (!context.mounted) {
      debugPrint(
        '[MessageUtils] Context not mounted, skipping message: $message',
      );
      return false;
    }

    try {
      if (PlatformUtils.isIOS) {
        // For iOS, use a simple dialog
        await showPlatformDialog(
          context: context,
          builder: (dialogContext) => PlatformAlertDialog(
            title: Text(title ?? (isSuccess ? 'Success' : 'Error')),
            content: Text(message),
            actions: [
              PlatformDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
        );
        return true;
      } else {
        // For Android, try to use ScaffoldMessenger if available
        try {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null && context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isSuccess
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return true;
          } else {
            // Fallback to dialog if ScaffoldMessenger is not available
            if (context.mounted) {
              await showPlatformDialog(
                context: context,
                builder: (dialogContext) => PlatformAlertDialog(
                  title: Text(title ?? (isSuccess ? 'Success' : 'Error')),
                  content: Text(message),
                  actions: [
                    PlatformDialogAction(
                      child: const Text('OK'),
                      onPressed: () {
                        if (Navigator.canPop(dialogContext)) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                    ),
                  ],
                ),
              );
            }
            return true;
          }
        } catch (e) {
          debugPrint(
            '[MessageUtils] ScaffoldMessenger error: $e, falling back to dialog',
          );
          // Fallback to dialog if ScaffoldMessenger throws an error
          if (context.mounted) {
            await showPlatformDialog(
              context: context,
              builder: (dialogContext) => PlatformAlertDialog(
                title: Text(title ?? (isSuccess ? 'Success' : 'Error')),
                content: Text(message),
                actions: [
                  PlatformDialogAction(
                    child: const Text('OK'),
                    onPressed: () {
                      if (Navigator.canPop(dialogContext)) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ],
              ),
            );
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('[MessageUtils] Failed to show message: $e');
      return false;
    }
  }

  /// Shows a success message
  static Future<bool> showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return showMessage(context, message, isSuccess: true, title: title);
  }

  /// Shows an error message
  static Future<bool> showError(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return showMessage(context, message, isSuccess: false, title: title);
  }

  /// Safely shows a message after a delay to ensure context is stable
  static Future<bool> showMessageSafely(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    String? title,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    await Future.delayed(delay);
    if (context.mounted) {
      return showMessage(context, message, isSuccess: isSuccess, title: title);
    }
    return false;
  }
}
