import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'platform_utils.dart';

class MessageUtils {
  static Future<bool> showMessage(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    String? title,
  }) async {
    if (!context.mounted) {
      debugPrint(
        '[MessageUtils] Context not mounted, skipping message: $message',
      );
      return false;
    }

    try {
      if (PlatformUtils.isIOS) {
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

  static Future<bool> showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return showMessage(context, message, isSuccess: true, title: title);
  }

  static Future<bool> showError(
    BuildContext context,
    String message, {
    String? title,
  }) {
    return showMessage(context, message, isSuccess: false, title: title);
  }

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
