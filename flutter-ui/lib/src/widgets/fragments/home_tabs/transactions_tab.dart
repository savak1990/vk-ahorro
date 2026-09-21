import 'package:flutter/material.dart';
import '../../../models/filter_option.dart';
import '../../date_filter_bottom_sheet.dart';
import 'package:ahorro_ui/src/widgets/filters_bottom_sheet.dart';
import '../../../models/grouping_type.dart';
import '../../../models/date_filter_type.dart';
import '../../grouped_transactions_sliver.dart';
import '../../active_filters_summary.dart';
import '../../active_date_filters_summary.dart';
import '../../../screens/transaction_details_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_entries_provider.dart';
import '../../../providers/transactions_filter_provider.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_strings.dart';
import '../../typography.dart';
import '../../../utils/message_utils.dart';

class TransactionsTab extends StatefulWidget {
  final String? initialType;
  final String? initialCurrency;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const TransactionsTab({
    super.key,
    this.initialType,
    this.initialCurrency,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  bool _showAppBarTitle = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Данные транзакций загружаются при старте приложения через AppStateProvider.initializeApp()
    // Если заданы начальные фильтры, выставляем их через провайдер после первой сборки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialFilters();
    });

    // Добавляем слушатель скролла
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Показываем заголовок в AppBar когда скроллим вниз больше 100px
    final showTitle = _scrollController.offset > 100;
    if (showTitle != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = showTitle;
      });
    }
  }

  void _refreshTransactions() {
    Provider.of<TransactionEntriesProvider>(
      context,
      listen: false,
    ).loadEntries();
  }

  void _applyInitialFilters() {
    final filter = Provider.of<TransactionsFilterProvider>(
      context,
      listen: false,
    );
    final entriesProvider = Provider.of<TransactionEntriesProvider>(
      context,
      listen: false,
    );

    // Сначала очищаем все фильтры
    filter.clearAllFilters();

    // Фильтр по типу транзакции
    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      filter.toggleType(widget.initialType!, true);
    }

    // Фильтр по периоду дат
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      filter.setDateFilterType(DateFilterType.period);
      filter.setStartDate(widget.initialStartDate);
      filter.setEndDate(widget.initialEndDate);
    }

    // Фильтр по валюте (через фильтр аккаунтов, поскольку валюта связана с балансом)
    if (widget.initialCurrency != null && widget.initialCurrency!.isNotEmpty) {
      // Если entries уже загружены, применяем фильтр сразу
      if (entriesProvider.entries.isNotEmpty) {
        _filterAccountsByCurrency(filter, widget.initialCurrency!);
      } else {
        // Если entries еще не загружены, ждем их загрузки
        _waitForEntriesAndApplyCurrencyFilter(filter, widget.initialCurrency!);
      }
    }
  }

  void _filterAccountsByCurrency(
    TransactionsFilterProvider filter,
    String currency,
  ) {
    // Получаем все доступные аккаунты и находим те, которые связаны с указанной валютой
    final entriesProvider = Provider.of<TransactionEntriesProvider>(
      context,
      listen: false,
    );
    if (entriesProvider.entries.isNotEmpty) {
      // Собираем все уникальные комбинации кошелек-валюта
      final walletCurrencyMap = <String, String>{};
      for (final entry in entriesProvider.entries) {
        walletCurrencyMap[entry.balanceTitle] = entry.balanceCurrency;
      }

      debugPrint('[TRANSACTIONS] All wallets and currencies:');
      walletCurrencyMap.forEach((wallet, curr) {
        debugPrint('[TRANSACTIONS] - $wallet: $curr');
      });

      final accountsWithCurrency = entriesProvider.entries
          .where((entry) => entry.balanceCurrency == currency)
          .map((entry) => entry.balanceTitle)
          .toSet();

      debugPrint(
        '[TRANSACTIONS] Filtering for currency $currency, found accounts: $accountsWithCurrency',
      );

      // Применяем фильтр по найденным аккаунтам
      for (final account in accountsWithCurrency) {
        filter.toggleAccount(account, true);
      }
    }
  }

  void _waitForEntriesAndApplyCurrencyFilter(
    TransactionsFilterProvider filter,
    String currency,
  ) {
    // Используем addPostFrameCallback для повторной попытки после следующего кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final entriesProvider = Provider.of<TransactionEntriesProvider>(
        context,
        listen: false,
      );
      if (entriesProvider.entries.isNotEmpty) {
        _filterAccountsByCurrency(filter, currency);
      } else if (!entriesProvider.isLoading) {
        // Если entries все еще пусты и загрузка не происходит, попробуем загрузить
        entriesProvider.loadEntries().then((_) {
          _filterAccountsByCurrency(filter, currency);
        });
      } else {
        // Попробуем еще раз через небольшую задержку
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _waitForEntriesAndApplyCurrencyFilter(filter, currency);
          }
        });
      }
    });
  }

  // moved to provider

  // moved to provider

  // Группировка перенесена в провайдер

  void _showDateFilterBottomSheet() async {
    final filter = Provider.of<TransactionsFilterProvider>(
      context,
      listen: false,
    );
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => DateFilterBottomSheet(
          initialFilterType: filter.dateFilterType.name,
          initialYear: filter.selectedYear,
          initialMonth: filter.selectedMonth,
          initialStartDate: filter.startDate,
          initialEndDate: filter.endDate,
          availableYears: filter.availableYears,
        ),
      ),
    );

    if (result != null) {
      final String typeStr = result['filterType'] as String;
      filter.setDateFilterType(
        typeStr == 'period' ? DateFilterType.period : DateFilterType.month,
      );
      filter.setYear(result['year']);
      filter.setMonth(result['month']);
      filter.setStartDate(result['startDate']);
      filter.setEndDate(result['endDate']);
      _refreshTransactions();
    }
  }

  void _clearAllFilters() {
    Provider.of<TransactionsFilterProvider>(
      context,
      listen: false,
    ).clearAllFilters();
    _refreshTransactions();
  }

  // removed: icon mapping now handled via Category.getCategoryIcon in provider

  List<FilterOption> _getTypeFilterOptions() =>
      Provider.of<TransactionsFilterProvider>(
        context,
        listen: false,
      ).getTypeFilterOptions();

  List<FilterOption> _getAccountFilterOptions() =>
      Provider.of<TransactionsFilterProvider>(
        context,
        listen: false,
      ).getAccountFilterOptions();

  List<FilterOption> _getCategoryFilterOptions() =>
      Provider.of<TransactionsFilterProvider>(
        context,
        listen: false,
      ).getCategoryFilterOptions();

  // moved to provider

  // moved to provider

  // moved to provider

  void _showFiltersBottomSheet() async {
    final result = await showModalBottomSheet<Map<String, Set<String>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => FiltersBottomSheet(
          typeOptions: _getTypeFilterOptions(),
          accountOptions: _getAccountFilterOptions(),
          categoryOptions: _getCategoryFilterOptions(),
          initialSelectedTypes: Provider.of<TransactionsFilterProvider>(
            context,
            listen: false,
          ).selectedTypes,
          initialSelectedAccounts: Provider.of<TransactionsFilterProvider>(
            context,
            listen: false,
          ).selectedAccounts,
          initialSelectedCategories: Provider.of<TransactionsFilterProvider>(
            context,
            listen: false,
          ).selectedCategories,
        ),
      ),
    );

    if (result != null) {
      debugPrint('Filters result: $result');
      Provider.of<TransactionsFilterProvider>(
        context,
        listen: false,
      ).updateSelections(
        types: result['types'],
        accounts: result['accounts'],
        categories: result['categories'],
      );
      debugPrint('Updated filters via provider');
    }
  }

  void _showGroupingOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Group by', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              trailing:
                  Provider.of<TransactionsFilterProvider>(
                        context,
                        listen: false,
                      ).groupingType ==
                      GroupingType.date
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                Provider.of<TransactionsFilterProvider>(
                  context,
                  listen: false,
                ).setGroupingType(GroupingType.date);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Category'),
              trailing:
                  Provider.of<TransactionsFilterProvider>(
                        context,
                        listen: false,
                      ).groupingType ==
                      GroupingType.category
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                Provider.of<TransactionsFilterProvider>(
                  context,
                  listen: false,
                ).setGroupingType(GroupingType.category);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final DateTime month = args?['month'] ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: _showAppBarTitle
            ? Text(
                AppStrings.transactionsTitle,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              )
            : const Text(''),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        bottom:
            (Provider.of<TransactionsFilterProvider>(
                  context,
                ).hasActiveDateFilters ||
                Provider.of<TransactionsFilterProvider>(
                  context,
                ).hasActiveNonDateFilters)
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                  (Provider.of<TransactionsFilterProvider>(
                            context,
                          ).hasActiveDateFilters
                          ? 56
                          : 0) +
                      (Provider.of<TransactionsFilterProvider>(
                            context,
                          ).hasActiveNonDateFilters
                          ? 56
                          : 0) +
                      (Provider.of<TransactionsFilterProvider>(
                                context,
                              ).hasActiveDateFilters &&
                              Provider.of<TransactionsFilterProvider>(
                                context,
                              ).hasActiveNonDateFilters
                          ? 4
                          : 0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (Provider.of<TransactionsFilterProvider>(
                      context,
                    ).hasActiveDateFilters)
                      ActiveDateFiltersSummary(
                        dateFilterType: Provider.of<TransactionsFilterProvider>(
                          context,
                        ).dateFilterType,
                        selectedYear: Provider.of<TransactionsFilterProvider>(
                          context,
                        ).selectedYear,
                        selectedMonth: Provider.of<TransactionsFilterProvider>(
                          context,
                        ).selectedMonth,
                        startDate: Provider.of<TransactionsFilterProvider>(
                          context,
                        ).startDate,
                        endDate: Provider.of<TransactionsFilterProvider>(
                          context,
                        ).endDate,
                        onClear: () => Provider.of<TransactionsFilterProvider>(
                          context,
                          listen: false,
                        ).clearDateFilters(),
                      ),
                    if (Provider.of<TransactionsFilterProvider>(
                          context,
                        ).hasActiveDateFilters &&
                        Provider.of<TransactionsFilterProvider>(
                          context,
                        ).hasActiveNonDateFilters)
                      const SizedBox(height: 4),
                    if (Provider.of<TransactionsFilterProvider>(
                      context,
                    ).hasActiveNonDateFilters)
                      ActiveFiltersSummary(
                        selectedTypes: Provider.of<TransactionsFilterProvider>(
                          context,
                        ).selectedTypes,
                        selectedAccounts:
                            Provider.of<TransactionsFilterProvider>(
                              context,
                            ).selectedAccounts,
                        selectedCategories:
                            Provider.of<TransactionsFilterProvider>(
                              context,
                            ).selectedCategories,
                        onClear: _clearAllFilters,
                      ),
                  ],
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.format_list_bulleted,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: _showGroupingOptions,
          ),
          IconButton(
            icon: Icon(Icons.tune, color: colorScheme.onSurfaceVariant),
            onPressed: _showFiltersBottomSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: _showDateFilterBottomSheet,
          ),
        ],
      ),
      body: Consumer2<TransactionEntriesProvider, TransactionsFilterProvider>(
        builder: (context, entriesProvider, filterProvider, _) {
          if (entriesProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entriesProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading transactions',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _refreshTransactions,
                    child: Text(
                      'Retry',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Преобразуем entries в display-структуру (группировка и т.д.)
          // Передаём entries провайдеру фильтров после кадра, чтобы избежать notify во время build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            filterProvider.setEntries(entriesProvider.entries);

            // Если у нас есть фильтр по валюте, который еще не был применен, применяем его сейчас
            if (widget.initialCurrency != null &&
                widget.initialCurrency!.isNotEmpty &&
                filterProvider.selectedAccounts.isEmpty) {
              _filterAccountsByCurrency(
                filterProvider,
                widget.initialCurrency!,
              );
            }
          });

          // Получаем сгруппированные данные из провайдера
          final groupedTransactions = filterProvider.groupedTransactions;

          if (groupedTransactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (filterProvider.hasActiveDateFilters ||
                            filterProvider.hasActiveNonDateFilters)
                        ? 'with current filters'
                        : 'for ${_getMonthName(month)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refreshTransactions();
              // Ждем немного, чтобы показать анимацию
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              controller: _scrollController, // Добавляем контроллер скролла
              slivers: [
                // Большой заголовок Transactions как часть экрана
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.horizontalPadding,
                      24,
                      AppConstants.horizontalPadding,
                      AppConstants.screenPadding,
                    ),
                    child: const HeadlineEmphasizedLarge(
                      text: AppStrings.transactionsTitle,
                    ),
                  ),
                ),
                // Список транзакций
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.horizontalPadding,
                    vertical: 8,
                  ),
                  sliver: GroupedTransactionsSliver(
                    groupedTransactions: groupedTransactions,
                    onTapTransaction: (tx) async {
                      final result = await Navigator.of(context)
                          .push<Map<String, dynamic>?>(
                            MaterialPageRoute(
                              builder: (context) => TransactionDetailsScreen(
                                transactionId: tx.id,
                              ),
                            ),
                          );

                      // Handle result from transaction details screen
                      if (result != null && mounted) {
                        final bool success = result['success'] ?? false;
                        final String message = result['message'] ?? '';

                        if (success) {
                          await MessageUtils.showSuccess(context, message);
                        } else {
                          await MessageUtils.showError(context, message);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // moved to provider

  String _getMonthName(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[date.month - 1];
  }

  // moved to provider

  // moved to provider

  void _clearDateFilters() {
    Provider.of<TransactionsFilterProvider>(
      context,
      listen: false,
    ).clearDateFilters();
    _refreshTransactions();
  }

  // moved to provider

  // moved to separate widget

  // moved to separate widget
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// moved to ../models/transaction_display_data.dart
