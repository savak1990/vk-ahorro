import 'package:ahorro_ui/src/widgets/fragments/budgets_overview/budgets_overview_fragment.dart';
import 'package:ahorro_ui/src/widgets/fragments/transaction_stats/transaction_stats_fragment.dart';
import 'package:flutter/material.dart';

class HomeTabNew extends StatelessWidget {
  const HomeTabNew({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(flex: 5, child: TransactionStatsFragment()),
        Expanded(flex: 4, child: BudgetsOverviewFragment()),
      ],
    );
  }
}
