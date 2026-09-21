import 'package:ahorro_ui/src/widgets/fragments/transaction_stats/transaction_stats_chart.dart';
import 'package:ahorro_ui/src/widgets/fragments/transaction_stats/transaction_stats_list_view.dart';
import 'package:ahorro_ui/src/widgets/fragments/transaction_stats/transaction_stats_param_selector.dart';
import 'package:flutter/material.dart';

class TransactionStatsFragmentLayout extends StatelessWidget {
  final bool showFullscreenButton;
  final bool showListView;

  const TransactionStatsFragmentLayout({
    super.key,
    this.showFullscreenButton = true,
    this.showListView = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ensure the param selector is always visible with proper spacing
        TransactionStatsParamSelector(
          showFullscreenButton: showFullscreenButton,
        ),
        Expanded(
          flex: showListView ? 1 : 1, // Chart takes 50% when list is shown
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            child: const TransactionStatsChart(),
          ),
        ),
        if (showListView)
          Expanded(
            flex: 1, // List takes 50% when shown
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Transaction Details",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: TransactionStatsListView()),
              ],
            ),
          ),
      ],
    );
  }
}
