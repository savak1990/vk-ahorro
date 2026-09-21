import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Removed AppColors in favor of Theme.of(context).colorScheme

class TransactionTile extends StatelessWidget {
  final String type; // 'income', 'expense', 'movement'
  final double amount;
  final String category;
  final IconData categoryIcon;
  final String balance;
  final DateTime date;
  final String? description;
  final String currency;
  final String? merchantName;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const TransactionTile({
    super.key,
    required this.type,
    required this.amount,
    required this.category,
    required this.categoryIcon,
    required this.balance,
    required this.date,
    this.description,
    this.currency = 'EUR',
    this.merchantName,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isExpense = type == 'expense';
    final isIncome = type == 'income';
    
    // Определяем иконку типа транзакции (форма меняется, цвет фиксированный по теме)
    IconData typeIcon;
    if (isIncome) {
      typeIcon = Icons.trending_up;
    } else if (isExpense) {
      typeIcon = Icons.trending_down;
    } else {
      typeIcon = Icons.swap_horiz;
    }
    final Color iconColor = colorScheme.onSecondaryContainer;
    final Color iconBackgroundColor = colorScheme.secondaryContainer;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(16) : Radius.zero,
          topRight: isFirst ? const Radius.circular(16) : Radius.zero,
          bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(16) : Radius.zero,
          topRight: isFirst ? const Radius.circular(16) : Radius.zero,
          bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Иконка типа транзакции
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      typeIcon,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Основная информация
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Первая строка: категория
                        Text(
                          category,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Вторая строка: мерчант
                        Text(
                          (merchantName?.isNotEmpty == true) ? merchantName! : '-',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        // Третья строка: баланс и валюта
                        Text(
                          '$balance • $currency',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Сумма справа
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount.toStringAsFixed(2),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd-MM-yyyy').format(date),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  // Стрелка справа (если есть onTap)
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
            // Разделитель между элементами (кроме последнего)
            if (!isLast)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 76, // 16 + 44 + 16 (отступ + иконка + отступ)
                endIndent: 16,
              ),
          ],
        ),
      ),
    );
  }
} 