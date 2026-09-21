import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateFilterBottomSheet extends StatefulWidget {
  final String initialFilterType;
  final int? initialYear;
  final int? initialMonth;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Set<int> availableYears;

  const DateFilterBottomSheet({
    super.key,
    required this.initialFilterType,
    this.initialYear,
    this.initialMonth,
    this.initialStartDate,
    this.initialEndDate,
    required this.availableYears,
  });

  @override
  _DateFilterBottomSheetState createState() => _DateFilterBottomSheetState();
}

class _DateFilterBottomSheetState extends State<DateFilterBottomSheet> {
  late String _filterType;
  int? _selectedYear;
  int? _selectedMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  String _getMonthName(int month) {
    return DateFormat.MMMM().format(DateTime(2024, month));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    // Получаем безопасную область и высоту экрана
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    final screenHeight = mediaQuery.size.height;
    
    // Рассчитываем максимальную высоту: экран минус safe area сверху минус отступ
    final maxHeight = screenHeight - safeAreaTop - 20;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фиксированный заголовок
            Text(
              'Filter by Date',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'month', label: Text('Month')),
                ButtonSegment(value: 'period', label: Text('Period')),
              ],
              selected: {_filterType},
              onSelectionChanged: (Set<String> selected) {
                setState(() {
                  _filterType = selected.first;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Скроллируемый контент
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_filterType == 'month') ...[
                      _buildSectionTitle('Year'),
                      Wrap(
                        spacing: 8.0,
                        children: [null, ...widget.availableYears.toList()..sort()].map((year) {
                          return ChoiceChip(
                            label: Text(year?.toString() ?? 'All'),
                            selected: _selectedYear == year,
                            onSelected: (selected) {
                              setState(() {
                                _selectedYear = selected ? year : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Month'),
                      Wrap(
                        spacing: 8.0,
                        children: [null, ...List.generate(12, (i) => i + 1)].map((month) {
                          return ChoiceChip(
                            label: Text(month != null ? _getMonthName(month) : 'All'),
                            selected: _selectedMonth == month,
                            onSelected: (selected) {
                              setState(() {
                                _selectedMonth = selected ? month : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Start Date'),
                                _buildDateChip(
                                  date: _startDate,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _startDate = date;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('End Date'),
                                _buildDateChip(
                                  date: _endDate,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate ?? DateTime.now(),
                                      firstDate: _startDate ?? DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _endDate = date;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    ],
                    // Дополнительный отступ для скролла
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            
            // Фиксированная кнопка Apply
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'filterType': _filterType,
                  'year': _selectedYear,
                  'month': _selectedMonth,
                  'startDate': _startDate,
                  'endDate': _endDate,
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Apply'),
            ),
            const SizedBox(height: 16),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildDateChip({
    DateTime? date,
    required VoidCallback onTap,
  }) {
    return InputChip(
      label: Text(date != null ? DateFormat.yMd().format(date) : 'Select date'),
      onPressed: onTap,
      avatar: const Icon(Icons.calendar_today),
    );
  }
} 