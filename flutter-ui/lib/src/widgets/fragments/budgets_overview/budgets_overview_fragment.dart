import 'package:ahorro_ui/src/widgets/fragments/budgets_overview/budgets_overview_list_view.dart';
import 'package:flutter/material.dart';

class BudgetsOverviewFragment extends StatelessWidget {
  const BudgetsOverviewFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Budgets Overview",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Expanded(child: BudgetsOverviewListView()),
      ],
    );
  }
}
