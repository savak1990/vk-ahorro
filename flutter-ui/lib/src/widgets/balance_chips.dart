import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/balances_provider.dart';
import '../utils/platform_utils.dart';
import '../widgets/add_balance_form.dart';

class BalanceChips extends StatelessWidget {
  final String? selectedBalanceId;
  final ValueChanged<String?> onBalanceSelected;
  final bool allowDeselect;
  final String? title;
  final bool showAddButton;
  final List<String>? excludeBalanceIds;

  const BalanceChips({
    super.key,
    required this.selectedBalanceId,
    required this.onBalanceSelected,
    this.allowDeselect = true,
    this.title,
    this.showAddButton = true,
    this.excludeBalanceIds,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<BalancesProvider>(
      builder: (context, provider, _) {
        final balances = provider.balances;

        if (balances.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Чипы для выбора баланса
            Wrap(
              spacing: 8.0,
              children: [
                ...balances
                    .where((balance) => excludeBalanceIds == null || !excludeBalanceIds!.contains(balance.balanceId))
                    .map((balance) {
                  final selected = selectedBalanceId == balance.balanceId;
                  return ChoiceChip(
                    label: Text('${balance.title} • ${balance.currency}'),
                    selected: selected,
                    onSelected: (selected) {
                      if (selected) {
                        onBalanceSelected(balance.balanceId);
                      } else if (allowDeselect && selectedBalanceId == balance.balanceId) {
                        // Если пытаемся отжать выбранный баланс и это разрешено
                        if (balances.length > 1) {
                          // Выбираем первый доступный баланс
                          final firstBalance = balances.firstWhere((b) => b.balanceId != balance.balanceId);
                          onBalanceSelected(firstBalance.balanceId);
                        }
                      }
                    },
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PlatformUtils.adaptiveBorderRadius),
                    ),
                  );
                }),
              ],
            ),
            
            // Кнопка добавления нового баланса
            if (showAddButton) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: AddBalanceForm(),
                      ),
                    ).then((_) {
                      // Обновляем балансы после добавления нового
                      Provider.of<BalancesProvider>(context, listen: false).loadBalances(forceRefresh: true);
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add balance'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
} 