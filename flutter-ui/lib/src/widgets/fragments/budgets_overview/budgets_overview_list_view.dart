import 'package:flutter/material.dart';

class BudgetItem {
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final IconData icon;

  BudgetItem({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.icon,
  });

  double get percentage => (spentAmount / budgetAmount * 100).clamp(0, 999);
  bool get isOverBudget => spentAmount > budgetAmount;
  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';
}

class BudgetsOverviewListView extends StatelessWidget {
  const BudgetsOverviewListView({super.key});

  // Static sample data - sorted by percentage (highest first)
  List<BudgetItem> get _budgetItems {
    final items = [
      BudgetItem(
        category: 'Entertainment',
        budgetAmount: 200.0,
        spentAmount: 350.0,
        icon: Icons.movie,
      ),
      BudgetItem(
        category: 'Dining Out',
        budgetAmount: 300.0,
        spentAmount: 480.0,
        icon: Icons.restaurant,
      ),
      BudgetItem(
        category: 'Shopping',
        budgetAmount: 400.0,
        spentAmount: 520.0,
        icon: Icons.shopping_bag,
      ),
      BudgetItem(
        category: 'Transportation',
        budgetAmount: 250.0,
        spentAmount: 280.0,
        icon: Icons.directions_car,
      ),
      BudgetItem(
        category: 'Groceries',
        budgetAmount: 500.0,
        spentAmount: 450.0,
        icon: Icons.shopping_cart,
      ),
      BudgetItem(
        category: 'Utilities',
        budgetAmount: 150.0,
        spentAmount: 120.0,
        icon: Icons.bolt,
      ),
      BudgetItem(
        category: 'Healthcare',
        budgetAmount: 200.0,
        spentAmount: 85.0,
        icon: Icons.local_hospital,
      ),
    ];

    // Sort by percentage (highest first)
    items.sort((a, b) => b.percentage.compareTo(a.percentage));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _budgetItems.length,
      itemBuilder: (context, index) {
        final item = _budgetItems[index];
        return _buildBudgetListItem(context, item);
      },
    );
  }

  Widget _buildBudgetListItem(BuildContext context, BudgetItem item) {
    final theme = Theme.of(context);
    final progressColor = _getProgressColor(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Icon
            Icon(item.icon, size: 20, color: progressColor),
            const SizedBox(width: 12),

            // Category name (fixed width)
            SizedBox(
              width: 80,
              child: Text(
                item.category,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Progress bar with percentage overlay (expanded)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (item.percentage / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 20,
                    ),
                  ),
                  // Percentage text overlay
                  Text(
                    item.formattedPercentage,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount spent/budget
            Text(
              '\$${item.spentAmount.toStringAsFixed(0)}/\$${item.budgetAmount.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(BudgetItem item) {
    if (item.percentage >= 100) {
      return Colors.red; // Over budget
    } else if (item.percentage >= 80) {
      return Colors.orange; // Close to budget
    } else if (item.percentage >= 60) {
      return Colors.amber; // Moderate usage
    } else {
      return Colors.green; // Under budget
    }
  }
}
