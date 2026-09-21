import 'package:ahorro_ui/src/providers/transaction_stats_provider.dart';
import 'package:ahorro_ui/src/widgets/adaptive/adaptive_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionStatsChartTypeSelector extends StatelessWidget {
  const TransactionStatsChartTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TransactionStatsProvider, ChartType>(
      selector: (_, provider) => provider.selectedChartType,
      builder: (_, selectedChartType, _) {
        return AdaptiveDropdown<ChartType>(
          items: ChartType.values,
          selectedItem: selectedChartType,
          onChanged: (value) {
            if (value != null) {
              context.read<TransactionStatsProvider>().selectedChartType =
                  value;
            }
          },
          itemLabelBuilder: (item) {
            switch (item) {
              case ChartType.pie:
                return 'Pie';
              case ChartType.bar:
                return 'Bar';
              case ChartType.donut:
                return 'Donut';
              case ChartType.line:
                return 'Line';
            }
          },
        );
      },
    );
  }
}
