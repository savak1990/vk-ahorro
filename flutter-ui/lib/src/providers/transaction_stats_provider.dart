import 'dart:async';

import 'package:ahorro_ui/src/models/currencies.dart';
import 'package:ahorro_ui/src/models/transaction_stats.dart';
import 'package:ahorro_ui/src/services/api_service.dart';
import 'package:flutter/material.dart';

enum Period { year, quarter, month, week, day }

enum MainFilterOptions {
  byBalance,
  byCategory,
  byCurrency,
  byQuarter,
  byMonth,
  byWeek,
  byDay,
}

enum ChartType { pie, bar, donut, line }

class TransactionStatsProvider extends ChangeNotifier {
  TransactionStatsProvider() {
    // Initialize default values for _startDate and _endDate
    final now = DateTime.now();
    _startDate = DateTime(
      now.year,
      now.month,
      1,
    ); // Beginning of the current month
    _endDate = DateTime(now.year, now.month + 1, 0); // End of the current month
  }

  String? _categoryId;
  String? _balanceId;
  DateTime? _startDate;
  DateTime? _endDate;
  TransactionStatsType _type = TransactionStatsType.expense;
  TransactionStatsGrouping _grouping = TransactionStatsGrouping.category;
  CurrencyCode _currency = CurrencyCode.eur;
  int _limit = 10;
  String _sort = 'amount';
  String _order = 'desc';
  ChartType _selectedChartType = ChartType.pie;

  // Result state
  bool _loading = false;
  Object? _error;
  TransactionStatsResponse? _data;

  Timer? _debounce;
  int _requestToken = 0; // simple in-flight dropper

  bool get loading => _loading;
  Object? get error => _error;
  TransactionStatsResponse? get data => _data;

  // Public manual refresh (pull-to-refresh, retry button, etc.)
  Future<void> refresh() async => _fetch(immediate: true);

  // Debounce to avoid spamming API when user taps quickly
  void _scheduleFetch() {
    debugPrint('Scheduling fetch with debounce');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetch();
    });
  }

  Future<void> _fetch({bool immediate = false}) async {
    debugPrint(
      'Fetching transaction stats: '
      'start=$_startDate, end=$_endDate, type=$_type, '
      'grouping=$_grouping, currency=$_currency, '
      'categoryId=$_categoryId, balanceId=$_balanceId, '
      'limit=$_limit, sort=$_sort, order=$_order',
    );

    _debounce?.cancel();
    final token = ++_requestToken; // capture token for this call
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Call ApiService to fetch transaction stats
      final result = await ApiService.getTransactionStats(
        startDate: _startDate!,
        endDate: _endDate!,
        grouping: _grouping,
        type: _type,
        currency: _currency,
        categoryId: _categoryId,
        balanceId: _balanceId,
        limit: _limit,
        sort: _sort,
        order: _order,
      );

      // Only accept the latest response
      if (token == _requestToken) {
        _data = result;
        _loading = false;
        notifyListeners();
      }
    } catch (e) {
      if (token == _requestToken) {
        _error = e;
        _loading = false;
        notifyListeners();
      }
    }
  }

  set selectedMainFilter(MainFilterOptions option) {
    TransactionStatsGrouping newGrouping;
    DateTime? newStartDate;
    DateTime? newEndDate;
    final now = DateTime.now();

    switch (option) {
      case MainFilterOptions.byBalance:
      case MainFilterOptions.byCategory:
      case MainFilterOptions.byCurrency:
        // For byBalance, byCategory, byCurrency: show current month (day 1 to last day)
        if (option == MainFilterOptions.byBalance) {
          newGrouping = TransactionStatsGrouping.balance;
        } else if (option == MainFilterOptions.byCategory) {
          newGrouping = TransactionStatsGrouping.category;
        } else {
          newGrouping = TransactionStatsGrouping.currency;
        }
        newStartDate = DateTime(now.year, now.month, 1);
        newEndDate = DateTime(
          now.year,
          now.month + 1,
          0,
        ); // Last day of current month
        break;

      case MainFilterOptions.byQuarter:
        newGrouping = TransactionStatsGrouping.quarter;
        // Show last 4 quarters
        // Current date: 21 Aug 2025 (Q3 2025)
        // Show: Q4 2024, Q1 2025, Q2 2025, Q3 2025
        final currentQuarter = _getCurrentQuarter(now);
        final currentYear = now.year;

        // Start from Q4 of previous year
        newStartDate = DateTime(currentYear - 1, 10, 1); // Q4 2024 starts Oct 1
        newEndDate = _getQuarterEndDate(
          currentYear,
          currentQuarter,
        ); // End of current quarter
        break;

      case MainFilterOptions.byMonth:
        newGrouping = TransactionStatsGrouping.month;
        // Show last 6 months
        final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);
        newStartDate = sixMonthsAgo;
        newEndDate = DateTime(
          now.year,
          now.month + 1,
          0,
        ); // End of current month
        break;

      case MainFilterOptions.byWeek:
        newGrouping = TransactionStatsGrouping.week;
        // Show 8 weeks
        newStartDate = now.subtract(const Duration(days: 8 * 7));
        newEndDate = now;
        break;

      case MainFilterOptions.byDay:
        newGrouping = TransactionStatsGrouping.day;
        // Show 1 week (7 days)
        newStartDate = now.subtract(const Duration(days: 7));
        newEndDate = now;
        break;
    }

    bool hasChanges = false;

    if (_grouping != newGrouping) {
      _grouping = newGrouping;
      hasChanges = true;
    }

    if (_startDate != newStartDate || _endDate != newEndDate) {
      _startDate = newStartDate;
      _endDate = newEndDate;
      hasChanges = true;
    }

    if (hasChanges) {
      _scheduleFetch();
      notifyListeners();
    }
  }

  /// Helper method to get current quarter (1-4)
  int _getCurrentQuarter(DateTime date) {
    return ((date.month - 1) ~/ 3) + 1;
  }

  /// Helper method to get the end date of a specific quarter
  DateTime _getQuarterEndDate(int year, int quarter) {
    switch (quarter) {
      case 1: // Q1: Jan-Mar
        return DateTime(year, 3, 31);
      case 2: // Q2: Apr-Jun
        return DateTime(year, 6, 30);
      case 3: // Q3: Jul-Sep
        return DateTime(year, 9, 30);
      case 4: // Q4: Oct-Dec
        return DateTime(year, 12, 31);
      default:
        return DateTime(year, 12, 31);
    }
  }

  set selectedChartType(ChartType chartType) {
    if (_selectedChartType == chartType) return;
    _selectedChartType = chartType;
    notifyListeners();
  }

  ChartType get selectedChartType => _selectedChartType;

  set selectedPeriod(Period period) {
    final now = DateTime.now();
    DateTime? newStartDate;
    DateTime? newEndDate;

    switch (period) {
      case Period.year:
        newStartDate = DateTime(now.year - 1, now.month, now.day);
        newEndDate = now;
        break;
      case Period.quarter:
        newStartDate = DateTime(now.year, now.month - 3, now.day);
        newEndDate = now;
        break;
      case Period.month:
        newStartDate = DateTime(now.year, now.month - 1, now.day);
        newEndDate = now;
        break;
      case Period.week:
        newStartDate = now.subtract(const Duration(days: 7));
        newEndDate = now;
        break;
      case Period.day:
        newStartDate = now.subtract(const Duration(days: 1));
        newEndDate = now;
        break;
    }

    // Update only if values have changed
    if (_startDate != newStartDate || _endDate != newEndDate) {
      _startDate = newStartDate;
      _endDate = newEndDate;
      notifyListeners();
    }
  }

  void setSelectedDateRange(DateTime? start, DateTime? end) {
    if (_startDate == start && _endDate == end) return;
    _startDate = start;
    _endDate = end;
    _scheduleFetch();
    notifyListeners();
  }

  set selectedCategoryId(String? id) {
    if (_categoryId == id) return;
    _categoryId = id;
    _scheduleFetch();
    notifyListeners();
  }

  String? get selectedCategoryId => _categoryId;

  DateTime? get selectedStartDate => _startDate;
  DateTime? get selectedEndDate => _endDate;

  set selectedBalanceId(String? id) {
    if (_balanceId == id) return;
    _balanceId = id;
    _scheduleFetch();
    notifyListeners();
  }

  set selectedType(TransactionStatsType type) {
    if (_type == type) return;
    _type = type;
    _scheduleFetch();
    notifyListeners();
  }

  TransactionStatsType get selectedType => _type;

  String get selectedTypeLabel {
    switch (_type) {
      case TransactionStatsType.expense:
        return 'Expense';
      case TransactionStatsType.income:
        return 'Income';
    }
  }

  set selectedGrouping(TransactionStatsGrouping grouping) {
    if (_grouping == grouping) return;
    _grouping = grouping;
    _scheduleFetch();
    notifyListeners();
  }

  TransactionStatsGrouping get selectedGrouping => _grouping;

  /// Get the current main filter option based on the grouping
  MainFilterOptions get selectedMainFilter {
    switch (_grouping) {
      case TransactionStatsGrouping.balance:
        return MainFilterOptions.byBalance;
      case TransactionStatsGrouping.category:
        return MainFilterOptions.byCategory;
      case TransactionStatsGrouping.currency:
        return MainFilterOptions.byCurrency;
      case TransactionStatsGrouping.quarter:
        return MainFilterOptions.byQuarter;
      case TransactionStatsGrouping.month:
        return MainFilterOptions.byMonth;
      case TransactionStatsGrouping.week:
        return MainFilterOptions.byWeek;
      case TransactionStatsGrouping.day:
        return MainFilterOptions.byDay;
    }
  }

  set selectedCurrency(CurrencyCode currency) {
    if (_currency == currency) return;
    _currency = currency;
    _scheduleFetch();
    notifyListeners();
  }

  CurrencyCode get selectedCurrency => _currency;

  set selectedLimit(int limit) {
    if (_limit == limit) return;
    _limit = limit;
    _scheduleFetch();
    notifyListeners();
  }

  int get selectedLimit => _limit;

  set selectedSort(String newSort) {
    if (_sort == newSort) return;
    _sort = newSort;
    _scheduleFetch();
    notifyListeners();
  }

  String get selectedSort => _sort;

  set selectedOrder(String newOrder) {
    if (_order == newOrder) return;
    _order = newOrder;
    _scheduleFetch();
    notifyListeners();
  }

  String get selectedOrder => _order;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
