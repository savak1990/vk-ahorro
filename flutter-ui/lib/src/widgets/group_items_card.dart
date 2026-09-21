import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/transaction_display_data.dart';
import '../utils/platform_utils.dart';
import 'transaction_tile.dart';

class GroupItemsCard extends StatelessWidget {
  final List<TransactionDisplayData> items;
  final void Function(TransactionDisplayData) onTapTransaction;

  const GroupItemsCard({
    super.key,
    required this.items,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Column(
        children: [
          ...items.asMap().entries.map((entry) {
            final txIndex = entry.key;
            final tx = entry.value;
            return TransactionTile(
              type: tx.type,
              amount: tx.amount,
              category: tx.category,
              categoryIcon: tx.categoryIcon,
              balance: tx.account,
              date: tx.date,
              description: tx.description,
              merchantName: tx.merchantName,
              currency: tx.currency,
              isFirst: txIndex == 0,
              isLast: txIndex == items.length - 1,
              onTap: () => onTapTransaction(tx),
            );
          }),
        ],
      ),
    );
  }
}

