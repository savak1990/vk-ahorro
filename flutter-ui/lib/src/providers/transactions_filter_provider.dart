import 'package:flutter/material.dart';
import '../models/date_filter_type.dart';
import '../models/grouping_type.dart';
import '../models/transaction_entry_data.dart';
import '../models/transaction_display_data.dart';
import '../constants/app_strings.dart';
import '../models/category.dart';
import '../models/filter_option.dart';

class TransactionsFilterProvider extends ChangeNotifier {
  // Source data
  List<TransactionEntryData> _entries = [];

  // Filters state
  DateFilterType dateFilterType = DateFilterType.month;
  int? selectedYear;
  int? selectedMonth;
  DateTime? startDate;
  DateTime? endDate;

  final Set<String> selectedTypes = {};
  final Set<String> selectedAccounts = {};
  final Set<String> selectedCategories = {};

  GroupingType groupingType = GroupingType.date;

  // Derived
  Set<int> availableYears = {};
  Set<int> availableMonths = {};
  Set<String> availableAccounts = {};
  Set<String> availableTypes = {};
  Set<String> availableCategories = {};

  void setEntries(List<TransactionEntryData> entries) {
    if (identical(_entries, entries)) {
      return;
    }
    _entries = entries;
    _rebuildAvailableFilters();
    notifyListeners();
  }

  // Public getters
  bool get hasActiveDateFilters =>
      selectedYear != null ||
      selectedMonth != null ||
      startDate != null ||
      endDate != null;
  bool get hasActiveNonDateFilters =>
      selectedTypes.isNotEmpty ||
      selectedAccounts.isNotEmpty ||
      selectedCategories.isNotEmpty;

  // Filter options for sheets
  List<FilterOption> getTypeFilterOptions() {
    final options = <FilterOption>[
      const FilterOption(value: 'all', label: 'All Types', isAllOption: true),
    ];
    for (final type in availableTypes) {
      final icon = type == 'income'
          ? Icons.trending_up
          : type == 'expense'
              ? Icons.trending_down
              : Icons.swap_horiz;
      final color = type == 'income'
          ? Colors.green
          : type == 'expense'
              ? Colors.red
              : Colors.blue;
      options.add(FilterOption(
        value: type,
        label: _capitalize(type),
        icon: icon,
        color: color,
        count: _countBy((d) => d.type == type),
      ));
    }
    return options;
  }

  List<FilterOption> getAccountFilterOptions() {
    final options = <FilterOption>[
      const FilterOption(
          value: 'all', label: 'All Accounts', isAllOption: true),
    ];
    for (final acc in availableAccounts) {
      options.add(FilterOption(
        value: acc,
        label: acc,
        icon: Icons.account_balance,
        count: _countBy((d) => d.account == acc),
      ));
    }
    return options;
  }

  List<FilterOption> getCategoryFilterOptions() {
    final options = <FilterOption>[
      const FilterOption(
          value: 'all', label: 'All Categories', isAllOption: true),
    ];
    for (final cat in availableCategories) {
      options.add(FilterOption(
        value: cat,
        label: cat,
        icon: Category.getCategoryIcon(cat),
        // Считаем количество агрегированных транзакций, содержащих категорию
        count: _countBucketsWhereCategory(cat),
      ));
    }
    return options;
  }

  // Apply filters and group
  Map<String, List<TransactionDisplayData>> get groupedTransactions {
    // Строим агрегированные транзакции и применяем фильтры
    final buckets = _buildBuckets();
    final List<TransactionDisplayData> result = [];

    buckets.forEach((_, entries) {
      if (entries.isEmpty) return;

      // Агрегируем для отображения
      final aggregated = _aggregateEntriesToDisplay(entries);

      // Фильтры по дате (используем transactedAt)
      if (hasActiveDateFilters) {
        if (dateFilterType == DateFilterType.month) {
          if (selectedYear != null && aggregated.date.year != selectedYear) {
            return;
          }
          if (selectedMonth != null && aggregated.date.month != selectedMonth) {
            return;
          }
        } else if (dateFilterType == DateFilterType.period) {
          if (startDate != null && aggregated.date.isBefore(startDate!)) {
            return;
          }
          if (endDate != null && aggregated.date.isAfter(endDate!)) {
            return;
          }
        }
      }

      // Фильтры по типу/аккаунту по агрегированным полям
      if (selectedTypes.isNotEmpty) {
        final entryTypes = entries.map((e) => e.type).toSet();
        if (entryTypes.intersection(selectedTypes).isEmpty) return;
      }
      if (selectedAccounts.isNotEmpty &&
          !selectedAccounts.contains(aggregated.account)) {
        return;
      }

      // Фильтр по категории должен проверять категории на уровне записей
      if (selectedCategories.isNotEmpty) {
        final entryCategories = entries.map((e) => e.categoryName).toSet();
        if (entryCategories.intersection(selectedCategories).isEmpty) return;
      }

      result.add(aggregated);
    });

    return _group(result);
  }

  // Mutators
  void setGroupingType(GroupingType type) {
    groupingType = type;
    notifyListeners();
  }

  void setDateFilterType(DateFilterType type) {
    dateFilterType = type;
    notifyListeners();
  }

  void setYear(int? year) {
    selectedYear = year;
    notifyListeners();
  }

  void setMonth(int? month) {
    selectedMonth = month;
    notifyListeners();
  }

  void setStartDate(DateTime? date) {
    startDate = date;
    notifyListeners();
  }

  void setEndDate(DateTime? date) {
    endDate = date;
    notifyListeners();
  }

  void clearDateFilters() {
    selectedYear = null;
    selectedMonth = null;
    startDate = null;
    endDate = null;
    notifyListeners();
  }

  void toggleType(String value, bool selected) {
    if (value == 'all') {
      selectedTypes.clear();
    } else {
      if (selected) {
        selectedTypes.add(value);
      } else {
        selectedTypes.remove(value);
      }
    }
    notifyListeners();
  }

  void toggleAccount(String value, bool selected) {
    if (value == 'all') {
      selectedAccounts.clear();
    } else {
      if (selected) {
        selectedAccounts.add(value);
      } else {
        selectedAccounts.remove(value);
      }
    }
    notifyListeners();
  }

  void toggleCategory(String value, bool selected) {
    if (value == 'all') {
      selectedCategories.clear();
    } else {
      if (selected) {
        selectedCategories.add(value);
      } else {
        selectedCategories.remove(value);
      }
    }
    notifyListeners();
  }

  void clearAllFilters() {
    selectedTypes.clear();
    selectedAccounts.clear();
    selectedCategories.clear();
    clearDateFilters();
    notifyListeners();
  }

  void updateSelections(
      {Set<String>? types, Set<String>? accounts, Set<String>? categories}) {
    if (types != null) {
      selectedTypes
        ..clear()
        ..addAll(types);
    }
    if (accounts != null) {
      selectedAccounts
        ..clear()
        ..addAll(accounts);
    }
    if (categories != null) {
      selectedCategories
        ..clear()
        ..addAll(categories);
    }
    notifyListeners();
  }

  // Internals
  void _rebuildAvailableFilters() {
    final display = _buildAggregatedDisplay();
    // Даты, аккаунты и типы считаем по агрегированным транзакциям (теперь используем transactedAt)
    availableYears = display.map((t) => t.date.year).toSet();
    availableMonths = display.map((t) => t.date.month).toSet();
    availableAccounts = display.map((t) => t.account).toSet();
    availableTypes = display.map((t) => t.type).toSet();
    // Категории считаем по исходным записям, чтобы не предлагать "Multiple categories"
    availableCategories = _entries.map((e) => e.categoryName).toSet();
  }

  int _countBy(bool Function(TransactionDisplayData) predicate) {
    final display = _buildAggregatedDisplay();
    return display.where(predicate).length;
  }

  int _countBucketsWhereCategory(String categoryName) {
    final buckets = _buildBuckets();
    int count = 0;
    for (final entries in buckets.values) {
      final cats = entries.map((e) => e.categoryName).toSet();
      if (cats.contains(categoryName)) count++;
    }
    return count;
  }

  // Преобразует входные записи в агрегированные транзакции.
  // Правила агрегации зависят от типа группировки:
  //
  // BY DATE:
  // - группируем по: transactionId + transactedAt + balanceTitle + balanceCurrency
  // - amount: сумма по всем записям
  // - category: если разные категории -> "Multiple categories", иначе - название категории
  //
  // BY CATEGORY:
  // - группируем по: categoryName + transactionId + balanceTitle + balanceCurrency + transactedAt
  // - amount: сумма по всем записям
  // - category: categoryName (всегда одинаковая в группе)
  Map<String, List<TransactionEntryData>> _buildBuckets() {
    final Map<String, List<TransactionEntryData>> buckets = {};

    for (final entry in _entries) {
      final String key;

      if (groupingType == GroupingType.category) {
        // Для группировки по категориям включаем categoryName в ключ
        key = [
          entry.categoryName,
          entry.transactionId,
          entry.balanceTitle,
          entry.balanceCurrency,
          entry.transactedAt.toIso8601String(),
        ].join('||');
      } else {
        // Для группировки по дате - стандартная агрегация по транзакции
        key = [
          entry.transactionId,
          entry.transactedAt.toIso8601String(),
          entry.balanceTitle,
          entry.balanceCurrency,
        ].join('||');
      }

      buckets.putIfAbsent(key, () => <TransactionEntryData>[]).add(entry);
    }
    return buckets;
  }

  TransactionDisplayData _aggregateEntriesToDisplay(
      List<TransactionEntryData> entries) {
    final first = entries.first;
    final double totalAmount =
        entries.fold<double>(0.0, (sum, e) => sum + e.amount);

    final Set<String> categories = entries.map((e) => e.categoryName).toSet();
    final String categoryLabel;
    final IconData categoryIcon;

    if (groupingType == GroupingType.category) {
      // При группировке по категориям все записи в группе имеют одинаковую категорию
      categoryLabel = first.categoryName;
      categoryIcon = Category.getCategoryIcon(first.categoryName);
    } else {
      // При группировке по дате проверяем количество уникальных категорий
      categoryLabel =
          categories.length == 1 ? first.categoryName : 'Multiple categories';
      categoryIcon = categories.length == 1
          ? Category.getCategoryIcon(first.categoryName)
          : Icons.category;
    }

    return TransactionDisplayData(
      id: first.transactionId,
      type: first.type,
      amount: totalAmount,
      category: categoryLabel,
      categoryIcon: categoryIcon,
      account: first.balanceTitle,
      merchantName: first.merchantName,
      date: first.transactedAt,
      currency: first.balanceCurrency,
    );
  }

  List<TransactionDisplayData> _buildAggregatedDisplay() {
    final buckets = _buildBuckets();
    final List<TransactionDisplayData> aggregated = [];
    for (final entries in buckets.values) {
      if (entries.isEmpty) continue;
      aggregated.add(_aggregateEntriesToDisplay(entries));
    }
    return aggregated;
  }

  Map<String, List<TransactionDisplayData>> _group(
      List<TransactionDisplayData> txs) {
    if (groupingType == GroupingType.category) {
      final Map<String, List<TransactionDisplayData>> grouped = {};
      for (final t in txs) {
        grouped.putIfAbsent(t.category, () => []).add(t);
      }
      final sortedKeys = grouped.keys.toList()..sort();
      final Map<String, List<TransactionDisplayData>> sorted = {};
      for (final k in sortedKeys) {
        // Сортируем транзакции внутри категории по transactedAt (убывание - новые сверху)
        final sortedTxs = grouped[k]!..sort((a, b) => b.date.compareTo(a.date));
        sorted[k] = sortedTxs;
      }
      return sorted;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<TransactionDisplayData>> grouped = {
      AppStrings.groupToday: [],
      AppStrings.groupYesterday: [],
      AppStrings.groupPrevious7Days: [],
      AppStrings.groupEarlier: [],
    };

    for (final t in txs) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      if (d == today) {
        grouped[AppStrings.groupToday]!.add(t);
      } else if (d == yesterday) {
        grouped[AppStrings.groupYesterday]!.add(t);
      } else if (d.isAfter(weekAgo) && d.isBefore(today)) {
        grouped[AppStrings.groupPrevious7Days]!.add(t);
      } else {
        grouped[AppStrings.groupEarlier]!.add(t);
      }
    }

    // Сортируем транзакции внутри каждой группы по transactedAt (убывание - новые сверху)
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.date.compareTo(a.date));
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
