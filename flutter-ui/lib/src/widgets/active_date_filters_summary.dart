import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/date_filter_type.dart';

class ActiveDateFiltersSummary extends StatelessWidget {
  final DateFilterType dateFilterType;
  final int? selectedYear;
  final int? selectedMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onClear;

  const ActiveDateFiltersSummary({
    super.key,
    required this.dateFilterType,
    required this.selectedYear,
    required this.selectedMonth,
    required this.startDate,
    required this.endDate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final filters = <String>[];
    if (dateFilterType == DateFilterType.month) {
      if (selectedYear != null) filters.add('Year: $selectedYear');
      if (selectedMonth != null) {
        final monthName = DateFormat.MMMM().format(DateTime(2024, selectedMonth!));
        filters.add('Month: $monthName');
      }
    } else if (dateFilterType == DateFilterType.period) {
      if (startDate != null) filters.add('Start: ${DateFormat('yyyy-MM-dd').format(startDate!)}');
      if (endDate != null) filters.add('End: ${DateFormat('yyyy-MM-dd').format(endDate!)}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(filters.join(', '))),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          )
        ],
      ),
    );
  }
}

