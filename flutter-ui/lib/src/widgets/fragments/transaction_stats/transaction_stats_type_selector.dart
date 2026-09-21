import 'package:ahorro_ui/src/models/transaction_stats.dart';
import 'package:ahorro_ui/src/providers/transaction_stats_provider.dart';
import 'package:ahorro_ui/src/widgets/adaptive/adaptive_segmented_single_choice_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionStatsTypeSelector extends StatelessWidget {
  const TransactionStatsTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TransactionStatsProvider, TransactionStatsType>(
      selector: (_, provider) => provider.selectedType,
      builder: (_, selectedType, _) {
        return AdaptiveSegmentedSingleChoiceButton<TransactionStatsType>(
          items: TransactionStatsType.values,
          selectedItem: selectedType,
          onChanged: (value) {
            context.read<TransactionStatsProvider>().selectedType = value;
          },
          itemWidgetBuilder: (item) {
            switch (item) {
              case TransactionStatsType.expense:
                return const Icon(Icons.trending_down);
              case TransactionStatsType.income:
                return const Icon(Icons.trending_up);
            }
          },
        );
      },
    );
  }
}
