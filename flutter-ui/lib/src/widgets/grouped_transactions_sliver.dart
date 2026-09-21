import 'package:flutter/material.dart';
import '../models/transaction_display_data.dart';
import 'group_items_card.dart';
import 'typography.dart';

class GroupedTransactionsSliver extends StatelessWidget {
  final Map<String, List<TransactionDisplayData>> groupedTransactions;
  final void Function(TransactionDisplayData) onTapTransaction;

  const GroupedTransactionsSliver({
    super.key,
    required this.groupedTransactions,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final groupKey = groupedTransactions.keys.elementAt(index);
          final groupItems = groupedTransactions[groupKey]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleEmphasizedLarge(
                  text: groupKey,
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                GroupItemsCard(
                  items: groupItems,
                  onTapTransaction: onTapTransaction,
                ),
              ],
            ),
          );
        },
        childCount: groupedTransactions.length,
      ),
    );
  }
}

