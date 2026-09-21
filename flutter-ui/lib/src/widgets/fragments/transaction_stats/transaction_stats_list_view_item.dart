import 'package:ahorro_ui/src/models/currencies.dart';
import 'package:ahorro_ui/src/models/transaction_stats.dart';
import 'package:flutter/material.dart';

class TransactionStatsListViewItem extends StatelessWidget {
  final TransactionStatsItem item;

  const TransactionStatsListViewItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: item.icon != null
            ? CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(item.icon!, style: const TextStyle(fontSize: 20)),
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.category,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
        title: Text(
          item.label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Text(
          formatAmountInt(item.amount, item.currency),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
      ),
    );
  }
}
