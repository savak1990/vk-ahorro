import 'package:flutter/material.dart';
import '../models/balance.dart';
// Removed AppColors in favor of Theme.of(context).colorScheme

class BalanceTile extends StatelessWidget {
  final Balance balance;
  final VoidCallback? onDelete;
  final bool useCardBackground;
  const BalanceTile({required this.balance, this.onDelete, this.useCardBackground = true, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDeleted = balance.deletedAt != null;
    final listTile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(Icons.account_balance_wallet, color: scheme.primary),
      title: Row(
        children: [
          Expanded(
            child: Text(
              balance.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                  ),
            ),
          ),
          if (isDeleted)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'deleted',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(balance.currency, style: Theme.of(context).textTheme.bodyMedium),
      trailing: (isDeleted || onDelete == null)
          ? null
          : IconButton(
              icon: Icon(Icons.delete, color: scheme.error),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
      onTap: () {
        // TODO: navigate to balance details
      },
    );

    final content = Opacity(
      opacity: isDeleted ? 0.5 : 1.0,
      child: useCardBackground
          ? Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: listTile,
            )
          : listTile,
    );

    return content;
  }
} 