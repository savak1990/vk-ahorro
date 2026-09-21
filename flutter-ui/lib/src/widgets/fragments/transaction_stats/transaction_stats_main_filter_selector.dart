import 'package:ahorro_ui/src/providers/transaction_stats_provider.dart';
import 'package:ahorro_ui/src/widgets/adaptive/adaptive_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionStatsMainFilterSelector extends StatelessWidget {
  const TransactionStatsMainFilterSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TransactionStatsProvider, MainFilterOptions>(
      selector: (_, provider) => provider.selectedMainFilter,
      builder: (_, selectedMainFilter, _) {
        return AdaptiveDropdown<MainFilterOptions>(
          items: MainFilterOptions.values,
          selectedItem: selectedMainFilter,
          onChanged: (value) {
            if (value != null) {
              context.read<TransactionStatsProvider>().selectedMainFilter =
                  value;
            }
          },
          itemLabelBuilder: (item) {
            switch (item) {
              case MainFilterOptions.byCategory:
                return 'By Category';
              case MainFilterOptions.byBalance:
                return 'By Balance';
              case MainFilterOptions.byCurrency:
                return 'By Currency';
              case MainFilterOptions.byQuarter:
                return 'By Quarter';
              case MainFilterOptions.byMonth:
                return 'By Month';
              case MainFilterOptions.byWeek:
                return 'By Week';
              case MainFilterOptions.byDay:
                return 'By Day';
            }
          },
        );
      },
    );
  }
}
