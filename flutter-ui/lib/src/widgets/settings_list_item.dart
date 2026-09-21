import 'package:flutter/material.dart';

class SettingsListItem extends StatelessWidget {
  const SettingsListItem({
    super.key,
    required this.title,
    required this.leadingIcon,
    this.onTap,
    this.leadingColor,
    this.showChevron = true,
  });

  final String title;
  final IconData leadingIcon;
  final VoidCallback? onTap;
  final Color? leadingColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(leadingIcon, color: leadingColor ?? scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (showChevron)
              Icon(Icons.arrow_forward_ios, size: 18, color: scheme.secondary),
          ],
        ),
      ),
    );
  }
}
