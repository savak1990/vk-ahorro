import 'package:flutter/material.dart';
import '../models/transaction_entry_data.dart';
import '../constants/app_constants.dart';
import '../utils/platform_utils.dart';
import 'list_item_tile.dart';

class MonthlyOverviewCard extends StatelessWidget {
  final List<TransactionEntryData> entries;
  final void Function(String type)? onTap;

  const MonthlyOverviewCard({
    super.key,
    required this.entries,
    this.onTap,
  });

  Map<String, double> _calculateMonthlyTotals(List<TransactionEntryData> entries) {
    final currentMonth = DateTime.now();
    final Map<String, double> monthlyTotals = {
      'expense': 0.0,
      'income': 0.0,
    };
    for (final entry in entries) {
      final entryDate = entry.transactedAt;
      if (entryDate.year == currentMonth.year && entryDate.month == currentMonth.month) {
        final type = entry.type.toLowerCase();
        if (monthlyTotals.containsKey(type)) {
          monthlyTotals[type] = monthlyTotals[type]! + entry.amount;
        }
      }
    }
    return monthlyTotals;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthlyTotals = _calculateMonthlyTotals(entries);
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius)
      ),
      child: Column(
        children: [
          ListItemTile(
            title: 'Expense',
            subtitle: '${monthlyTotals['expense']?.toStringAsFixed(2) ?? '0.00'} EUR',
            icon: Icons.trending_down,
            iconColor: colorScheme.onSecondaryContainer,
            onTap: onTap != null ? () => onTap!('expense') : null,
          ),
          ListItemTile(
            title: 'Income',
            subtitle: '${monthlyTotals['income']?.toStringAsFixed(2) ?? '0.00'} EUR',
            icon: Icons.trending_up,
            iconColor: colorScheme.onSecondaryContainer,
            onTap: onTap != null ? () => onTap!('income') : null,
            showDivider: false,
          ),
        ],
      ),
    );
  }
} 