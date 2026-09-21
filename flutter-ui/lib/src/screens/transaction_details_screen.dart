import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../constants/app_typography.dart';
import '../widgets/typography.dart';
import '../constants/app_strings.dart';
import '../widgets/settings_section_card.dart';
import '../widgets/list_item_tile.dart';
import '../widgets/category_picker_dialog.dart';
import '../models/transaction_details.dart';
import '../models/transaction_update_payload.dart';
import '../providers/balances_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/transaction_entries_provider.dart';
import '../models/category.dart' as CategoryModel;
import '../utils/message_utils.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final String transactionId;
  const TransactionDetailsScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  TransactionDetails? transactionDetails;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchTransactionDetails();
  }

  Future<void> fetchTransactionDetails() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await ApiService.getTransactionById(widget.transactionId);
      final parsed = TransactionDetails.fromJson(data);
      if (kDebugMode) {
        try {
          debugPrint(
            '[TX_DETAILS] Loaded transaction ${widget.transactionId}: type=${parsed.type}, entries=${parsed.entries.length}',
          );
        } catch (logErr) {
          debugPrint('[TX_DETAILS] Logging error: $logErr');
        }
      }
      setState(() {
        transactionDetails = parsed;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Ошибка: $e';
        isLoading = false;
      });
    }
  }

  Color _typeColor(String type, ThemeData theme) {
    return theme.colorScheme.primary;
  }

  // Используем общий маппинг иконок категорий из getCategoryIcon (category_picker_dialog.dart)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteTransactionConfirmation(context),
            tooltip: AppStrings.transactionDeleteButton,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : transactionDetails == null
          ? const Center(child: Text('Нет данных'))
          : _buildDetails(context, theme, textTheme),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    ThemeData theme,
    TextTheme textTheme,
  ) {
    final tx = transactionDetails!;
    final String typeStr = tx.type.toString();
    final String displayType = typeStr.isNotEmpty
        ? typeStr[0].toUpperCase() + typeStr.substring(1)
        : '-';
    final allEntries = tx.entries;
    final entries = allEntries
        .where((e) => e.deletedAt == null)
        .toList(); // Исключаем удаленные entries
    final double totalAmount = entries.fold<double>(
      0.0,
      (acc, e) => acc + (e.amount / 100),
    );
    if (kDebugMode) {
      debugPrint(
        '[TX_DETAILS] Building UI: type=$typeStr, entries=${entries.length}',
      );
    }
    final balanceTitle = tx.balanceTitle ?? tx.balance?.title ?? '-';
    final currency = tx.balanceCurrency ?? tx.balance?.currency ?? 'EUR';
    final transactedAt = tx.transactedAt;
    final formattedTransactedAt = transactedAt != null
        ? DateFormat('dd.MM.yyyy').format(transactedAt)
        : '-';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GENERAL (тип и сумма)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeadlineEmphasizedLarge(text: displayType),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${totalAmount.toStringAsFixed(2)} ',
                            style: AppTypography.displayLarge.copyWith(
                              color: _typeColor(typeStr, theme),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currency,
                            style: AppTypography.titleLarge.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // INFORMATION
            const TitleEmphasizedLarge(
              text: AppStrings.transactionDetailsInformationTitle,
            ),
            const SizedBox(height: 8),
            SettingsSectionCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              children: [_walletTile(context, theme, balanceTitle)],
            ),
            const SizedBox(height: 24),
            // PERIOD
            const TitleEmphasizedLarge(
              text: AppStrings.transactionDetailsPeriodTitle,
            ),
            const SizedBox(height: 8),
            SettingsSectionCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              children: [
                ListItemTile(
                  title: 'Transacted at',
                  icon: Icons.calendar_today,
                  iconColor: theme.colorScheme.primary,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (formattedTransactedAt.isEmpty ||
                                formattedTransactedAt == '-')
                            ? 'unknown'
                            : formattedTransactedAt,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => _showDatePicker(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ENTRIES
            if (entries.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TitleEmphasizedLarge(
                    text: AppStrings.transactionDetailsEntriesTitle,
                  ),
                  if (!['move_in', 'move_out'].contains(
                    typeStr.toLowerCase(),
                  )) // Запретить добавление для move_in/move_out
                    IconButton(
                      onPressed: () => _showAddEntrySheet(context),
                      icon: Icon(
                        Icons.add,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      tooltip: 'Add new entry',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SettingsSectionCard(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < entries.length; i++)
                    Builder(
                      builder: (context) {
                        final e = entries[i];
                        final cat =
                            (e.categoryName ??
                                    e.category?.name ??
                                    e.name ??
                                    e.category?.categoryNameLegacy ??
                                    '-')
                                .toString();
                        final amt = e.amount / 100;
                        final desc = e.description ?? '';
                        final iconData = getCategoryIcon(cat);
                        final isEditingAllowed = ![
                          'move_in',
                          'move_out',
                        ].contains(tx.type.toLowerCase());
                        if (kDebugMode) {
                          debugPrint(
                            '[TX_DETAILS] Render Entry[$i]: Name="${e.name}", catResolved="$cat", iconCode=${iconData.codePoint}, family=${iconData.fontFamily}, desc="$desc"',
                          );
                        }
                        return ListItemTile(
                          title: cat,
                          subtitle: desc.toString().isNotEmpty
                              ? desc.toString()
                              : null,
                          icon: iconData,
                          iconColor: theme.colorScheme.primary,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                amt.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              if (isEditingAllowed)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            AppStrings.transactionDetailsEdit,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (entries.length >
                                        1) // Можно удалить только если entries больше 1
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: theme.colorScheme.error,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppStrings
                                                  .transactionDetailsDelete,
                                              style: TextStyle(
                                                color: theme.colorScheme.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditEntrySheet(context, e, i);
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(context, e, i);
                                    }
                                  },
                                )
                              else
                                Icon(
                                  Icons.lock,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                            ],
                          ),
                          onTap: isEditingAllowed
                              ? () => _showEditEntrySheet(context, e, i)
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _walletTile(
    BuildContext context,
    ThemeData theme,
    String balanceTitle,
  ) {
    final tx = transactionDetails!;
    final isChangeAllowed =
        tx.type.toLowerCase() == 'income' || tx.type.toLowerCase() == 'expense';
    final balancesProvider = context.watch<BalancesProvider>();
    final canTap =
        isChangeAllowed &&
        (balancesProvider.balances.where((b) => b.deletedAt == null).length >
            1);
    return ListItemTile(
      title: AppStrings.transactionDetailsWalletTitle,
      icon: Icons.account_balance_wallet,
      iconColor: theme.colorScheme.primary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (balanceTitle.isEmpty || balanceTitle == '-')
                ? AppStrings.transactionDetailsWalletUnknown
                : balanceTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (canTap) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      onTap: canTap
          ? () async {
              // ensure balances are loaded
              if (balancesProvider.balances.isEmpty &&
                  !balancesProvider.isLoading) {
                await balancesProvider.loadBalances(forceRefresh: true);
              }
              _showSelectBalanceSheet(context);
            }
          : () {
              final msg = !isChangeAllowed
                  ? AppStrings.transactionDetailsWalletChangeNotAllowed
                  : AppStrings.transactionDetailsWalletCreateMoreInfo;
              MessageUtils.showMessage(context, msg, isSuccess: false);
            },
    );
  }

  Future<void> _showSelectBalanceSheet(BuildContext context) async {
    final balancesProvider = context.read<BalancesProvider>();
    final balances = balancesProvider.balances
        .where((b) => b.deletedAt == null)
        .toList();
    final currentBalanceId =
        transactionDetails?.balanceId ?? transactionDetails?.balance?.balanceId;
    String? selectedBalanceId = currentBalanceId;
    bool submitting = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.transactionDetailsSelectWalletTitle,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: balances.length,
                        itemBuilder: (c, i) {
                          final b = balances[i];
                          final selected = selectedBalanceId == b.balanceId;
                          return ListTile(
                            leading: Icon(
                              Icons.account_balance_wallet,
                              color: selected
                                  ? Theme.of(ctx).colorScheme.primary
                                  : null,
                            ),
                            title: Text(b.title),
                            subtitle: Text(b.currency),
                            trailing: selected ? const Icon(Icons.check) : null,
                            onTap: submitting
                                ? null
                                : () {
                                    setModalState(() {
                                      selectedBalanceId = b.balanceId;
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text(
                              AppStrings.transactionDetailsCancel,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (selectedBalanceId == null ||
                                        selectedBalanceId == currentBalanceId) {
                                      Navigator.of(ctx).pop();
                                      return;
                                    }
                                    setModalState(() => submitting = true);
                                    try {
                                      // Use complete payload helper method for consistency
                                      final payload = _createCompletePayload(
                                        newBalanceId: selectedBalanceId,
                                      );

                                      debugPrint(
                                        '[TX_DETAILS] === UPDATE TRANSACTION BALANCE ===',
                                      );
                                      debugPrint(
                                        '[TX_DETAILS] Changing balanceId: $currentBalanceId -> $selectedBalanceId',
                                      );
                                      debugPrint(
                                        '[TX_DETAILS] Complete payload: ${jsonEncode(payload.toJson())}',
                                      );

                                      await ApiService.updateTransaction(
                                        transactionId: widget.transactionId,
                                        payload: payload,
                                      );

                                      // Update transaction entries provider to reflect changes
                                      if (mounted) {
                                        final entriesProvider = context
                                            .read<TransactionEntriesProvider>();
                                        await entriesProvider
                                            .refreshAfterTransactionUpdate();
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        '[TX_DETAILS] Failed to update transaction: $e',
                                      );
                                      if (mounted) {
                                        await MessageUtils.showError(
                                          context,
                                          'Ошибка обновления: $e',
                                        );
                                      }
                                      setModalState(() => submitting = false);
                                      return;
                                    }
                                    if (mounted) {
                                      Navigator.of(ctx).pop();
                                      await MessageUtils.showSuccess(
                                        context,
                                        AppStrings.transactionDetailsUpdated,
                                      );
                                      await fetchTransactionDetails();
                                    }
                                  },
                            child: submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    AppStrings.transactionDetailsConfirm,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final tx = transactionDetails;
    if (tx == null) return;

    final currentDate =
        tx.transactedAt ?? tx.approvedAt ?? tx.createdAt ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select transacted date',
    );

    if (pickedDate == null) return;

    // Show time picker
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDate),
      helpText: 'Select transacted time',
    );

    if (pickedTime == null) return;

    // Combine date and time
    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Update transaction with new transacted date
    await _updateTransactedDate(newDateTime);
  }

  /// Create a complete payload for transaction update with all fields populated
  TransactionUpdatePayload _createCompletePayload({
    String? newBalanceId,
    DateTime? newApprovedAt,
    DateTime? newTransactedAt,
  }) {
    final tx = transactionDetails!;

    // Create complete transaction entries (exclude deleted entries)
    final entriesPayload = <Map<String, dynamic>>[];
    for (final entry in tx.entries.where((e) => e.deletedAt == null)) {
      final categoryId = entry.categoryId ?? entry.category?.categoryId;
      if (categoryId != null && categoryId.isNotEmpty) {
        entriesPayload.add(
          TransactionUpdatePayload.createTransactionEntry(
            id:
                entry.transactionEntryId ??
                entry.id, // Include ID for existing entries
            description: entry.description,
            amount: entry.amount,
            categoryId: categoryId,
          ),
        );
      }
    }

    return TransactionUpdatePayload(
      userId: tx.userId,
      groupId: tx.groupId,
      balanceId: newBalanceId ?? tx.balanceId,
      type: tx.type,
      operationId:
          tx.operationId, // Use original operationId from transaction details
      approvedAt: newApprovedAt ?? tx.approvedAt,
      transactedAt:
          newTransactedAt ?? tx.transactedAt ?? tx.approvedAt ?? tx.createdAt,
      transactionEntries: entriesPayload.isNotEmpty ? entriesPayload : null,
      merchantId: tx.merchantId,
    );
  }

  Future<void> _updateTransactedDate(DateTime newTransactedAt) async {
    final tx = transactionDetails;
    if (tx == null) return;

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Create complete payload with the new transacted date (also update approved date to the same value)
      final payload = _createCompletePayload(
        newTransactedAt: newTransactedAt,
        newApprovedAt:
            newTransactedAt, // Set approved date to the same value as transacted date
      );

      debugPrint('[TX_DETAILS] === UPDATE TRANSACTED DATE ===');
      debugPrint(
        '[TX_DETAILS] Current transactedAt: ${tx.transactedAt?.toIso8601String()}',
      );
      debugPrint(
        '[TX_DETAILS] Current approvedAt: ${tx.approvedAt?.toIso8601String()}',
      );
      debugPrint(
        '[TX_DETAILS] New transactedAt: ${newTransactedAt.toIso8601String()}',
      );
      debugPrint(
        '[TX_DETAILS] New approvedAt: ${newTransactedAt.toIso8601String()}',
      );
      debugPrint(
        '[TX_DETAILS] Complete payload: ${jsonEncode(payload.toJson())}',
      );

      await ApiService.updateTransaction(
        transactionId: widget.transactionId,
        payload: payload,
      );

      // Update transaction entries provider to reflect changes
      if (mounted) {
        final entriesProvider = context.read<TransactionEntriesProvider>();
        await entriesProvider.refreshAfterTransactionUpdate();
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await MessageUtils.showSuccess(context, 'Date is changed');
        await fetchTransactionDetails(); // Refresh transaction data
      }
    } catch (e) {
      debugPrint('[TX_DETAILS] Failed to update transacted date: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await MessageUtils.showError(context, 'Error updating date: $e');
      }
    }
  }

  Future<void> _showAddEntrySheet(BuildContext context) async {
    final categoriesProvider = context.read<CategoriesProvider>();

    // Ensure categories are loaded
    if (categoriesProvider.categories.isEmpty &&
        !categoriesProvider.isLoading) {
      await categoriesProvider.loadCategories(forceRefresh: true);
    }

    String? selectedCategoryId;
    String selectedCategoryName = 'Select Category';
    String description = '';
    double amount = 0.0;
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Entry',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Category Picker
                    ListTile(
                      leading: Icon(
                        getCategoryIcon(selectedCategoryName),
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      title: const Text('Category'),
                      subtitle: Text(selectedCategoryName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: submitting
                          ? null
                          : () async {
                              final result =
                                  await Navigator.push<CategoryModel.Category>(
                                    ctx,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => CategoryPickerDialog(
                                            selectedCategoryId:
                                                selectedCategoryId,
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return SlideTransition(
                                              position: animation.drive(
                                                Tween(
                                                  begin: const Offset(0.0, 1.0),
                                                  end: Offset.zero,
                                                ).chain(
                                                  CurveTween(
                                                    curve: Curves.ease,
                                                  ),
                                                ),
                                              ),
                                              child: child,
                                            );
                                          },
                                    ),
                                  );
                              if (result != null) {
                                setModalState(() {
                                  selectedCategoryId = result.id;
                                  selectedCategoryName = result.name;
                                });
                              }
                            },
                    ),

                    const SizedBox(height: 16),

                    // Description Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !submitting,
                      onChanged: (value) => description = value,
                    ),

                    const SizedBox(height: 16),

                    // Amount Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null) amount = parsed;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (selectedCategoryId == null ||
                                        selectedCategoryId!.isEmpty) {
                                      await MessageUtils.showError(
                                        context,
                                        'Please select a category',
                                      );
                                      return;
                                    }

                                    if (amount <= 0) {
                                      await MessageUtils.showError(
                                        context,
                                        'Please enter a valid amount',
                                      );
                                      return;
                                    }

                                    setModalState(() => submitting = true);

                                    try {
                                      await _addNewTransactionEntry(
                                        categoryId: selectedCategoryId!,
                                        description: description,
                                        amount: (amount * 100)
                                            .round(), // Convert to cents
                                      );

                                      if (mounted) {
                                        Navigator.of(ctx).pop();
                                        await MessageUtils.showSuccess(
                                          context,
                                          'Entry added successfully',
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        '[TX_DETAILS] Failed to add entry: $e',
                                      );
                                      if (mounted) {
                                        await MessageUtils.showError(
                                          context,
                                          'Error adding entry: $e',
                                        );
                                      }
                                      setModalState(() => submitting = false);
                                    }
                                  },
                            child: submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditEntrySheet(
    BuildContext context,
    TransactionEntryDetails entry,
    int entryIndex,
  ) async {
    final categoriesProvider = context.read<CategoriesProvider>();

    // Ensure categories are loaded
    if (categoriesProvider.categories.isEmpty &&
        !categoriesProvider.isLoading) {
      await categoriesProvider.loadCategories(forceRefresh: true);
    }

    String? selectedCategoryId = entry.categoryId ?? entry.category?.categoryId;
    String selectedCategoryName =
        entry.categoryName ??
        entry.category?.name ??
        entry.category?.categoryNameLegacy ??
        'Select Category';
    String description = entry.description ?? '';
    double amount = entry.amount / 100.0; // Convert from cents to display value
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Entry',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Category Picker
                    ListTile(
                      leading: Icon(
                        getCategoryIcon(selectedCategoryName),
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      title: const Text('Category'),
                      subtitle: Text(selectedCategoryName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: submitting
                          ? null
                          : () async {
                              final result =
                                  await Navigator.push<CategoryModel.Category>(
                                    ctx,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => CategoryPickerDialog(
                                            selectedCategoryId:
                                                selectedCategoryId,
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return SlideTransition(
                                              position: animation.drive(
                                                Tween(
                                                  begin: const Offset(0.0, 1.0),
                                                  end: Offset.zero,
                                                ).chain(
                                                  CurveTween(
                                                    curve: Curves.ease,
                                                  ),
                                                ),
                                              ),
                                              child: child,
                                            );
                                          },
                                    ),
                                  );
                              if (result != null) {
                                setModalState(() {
                                  selectedCategoryId = result.id;
                                  selectedCategoryName = result.name;
                                });
                              }
                            },
                    ),

                    const SizedBox(height: 16),

                    // Description Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: description),
                      enabled: !submitting,
                      onChanged: (value) => description = value,
                    ),

                    const SizedBox(height: 16),

                    // Amount Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                        text: amount.toStringAsFixed(2),
                      ),
                      enabled: !submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null) amount = parsed;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (selectedCategoryId == null ||
                                        selectedCategoryId!.isEmpty) {
                                      await MessageUtils.showError(
                                        context,
                                        'Please select a category',
                                      );
                                      return;
                                    }

                                    setModalState(() => submitting = true);

                                    try {
                                      await _updateTransactionEntry(
                                        entryIndex: entryIndex,
                                        newCategoryId: selectedCategoryId!,
                                        newDescription: description,
                                        newAmount: (amount * 100)
                                            .round(), // Convert to cents
                                      );

                                      if (mounted) {
                                        Navigator.of(ctx).pop();
                                        await MessageUtils.showSuccess(
                                          context,
                                          'Entry updated successfully',
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        '[TX_DETAILS] Failed to update entry: $e',
                                      );
                                      if (mounted) {
                                        await MessageUtils.showError(
                                          context,
                                          'Error updating entry: $e',
                                        );
                                      }
                                      setModalState(() => submitting = false);
                                    }
                                  },
                            child: submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateTransactionEntry({
    required int entryIndex,
    required String newCategoryId,
    required String newDescription,
    required int newAmount,
  }) async {
    final tx = transactionDetails;
    if (tx == null || entryIndex >= tx.entries.length) return;

    debugPrint('[TX_DETAILS] === UPDATE TRANSACTION ENTRY ===');
    debugPrint('[TX_DETAILS] Entry index: $entryIndex');
    debugPrint('[TX_DETAILS] New categoryId: $newCategoryId');
    debugPrint('[TX_DETAILS] New description: "$newDescription"');
    debugPrint('[TX_DETAILS] New amount: $newAmount');

    // Create updated entries list (exclude deleted entries)
    final updatedEntries = <Map<String, dynamic>>[];
    final activeEntries = tx.entries.where((e) => e.deletedAt == null).toList();
    for (int i = 0; i < activeEntries.length; i++) {
      final entry = activeEntries[i];
      final categoryId = i == entryIndex
          ? newCategoryId
          : (entry.categoryId ?? entry.category?.categoryId);
      final description = i == entryIndex
          ? newDescription
          : (entry.description ?? '');
      final amount = i == entryIndex ? newAmount : entry.amount;

      if (categoryId != null && categoryId.isNotEmpty) {
        updatedEntries.add(
          TransactionUpdatePayload.createTransactionEntry(
            id:
                entry.transactionEntryId ??
                entry.id, // Include ID for all existing entries
            description: description.isNotEmpty ? description : null,
            amount: amount,
            categoryId: categoryId,
          ),
        );
      }
    }

    // Create complete payload with updated entries
    final payload = TransactionUpdatePayload(
      userId: tx.userId,
      groupId: tx.groupId,
      balanceId: tx.balanceId,
      type: tx.type,
      operationId: tx.operationId,
      approvedAt: tx.approvedAt,
      transactedAt: tx.transactedAt ?? tx.approvedAt ?? tx.createdAt,
      transactionEntries: updatedEntries,
      merchantId: tx.merchantId,
    );

    debugPrint(
      '[TX_DETAILS] Complete payload: ${jsonEncode(payload.toJson())}',
    );

    await ApiService.updateTransaction(
      transactionId: widget.transactionId,
      payload: payload,
    );

    // Update transaction entries provider to reflect changes
    if (mounted) {
      final entriesProvider = context.read<TransactionEntriesProvider>();
      await entriesProvider.refreshAfterTransactionUpdate();
    }

    // Refresh transaction data
    await fetchTransactionDetails();
  }

  Future<void> _addNewTransactionEntry({
    required String categoryId,
    required String description,
    required int amount,
  }) async {
    final tx = transactionDetails;
    if (tx == null) return;

    debugPrint('[TX_DETAILS] === ADD NEW TRANSACTION ENTRY ===');
    debugPrint('[TX_DETAILS] New categoryId: $categoryId');
    debugPrint('[TX_DETAILS] New description: "$description"');
    debugPrint('[TX_DETAILS] New amount: $amount');

    // Create updated entries list including the new entry
    final updatedEntries = <Map<String, dynamic>>[];

    // Add existing entries with their IDs (exclude deleted entries)
    for (final entry in tx.entries.where((e) => e.deletedAt == null)) {
      final existingCategoryId = entry.categoryId ?? entry.category?.categoryId;
      if (existingCategoryId != null && existingCategoryId.isNotEmpty) {
        updatedEntries.add(
          TransactionUpdatePayload.createTransactionEntry(
            id:
                entry.transactionEntryId ??
                entry.id, // Include ID for existing entries
            description: entry.description,
            amount: entry.amount,
            categoryId: existingCategoryId,
          ),
        );
      }
    }

    // Add new entry without ID
    updatedEntries.add(
      TransactionUpdatePayload.createTransactionEntry(
        description: description.isNotEmpty ? description : null,
        amount: amount,
        categoryId: categoryId,
      ),
    );

    // Create complete payload with updated entries
    final payload = TransactionUpdatePayload(
      userId: tx.userId,
      groupId: tx.groupId,
      balanceId: tx.balanceId,
      type: tx.type,
      operationId: tx.operationId,
      approvedAt: tx.approvedAt,
      transactedAt: tx.transactedAt ?? tx.approvedAt ?? tx.createdAt,
      transactionEntries: updatedEntries,
      merchantId: tx.merchantId,
    );

    debugPrint(
      '[TX_DETAILS] Complete payload: ${jsonEncode(payload.toJson())}',
    );

    await ApiService.updateTransaction(
      transactionId: widget.transactionId,
      payload: payload,
    );

    // Update transaction entries provider to reflect changes
    if (mounted) {
      final entriesProvider = context.read<TransactionEntriesProvider>();
      await entriesProvider.refreshAfterTransactionUpdate();
    }

    // Refresh transaction data
    await fetchTransactionDetails();
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    TransactionEntryDetails entry,
    int entryIndex,
  ) async {
    final tx = transactionDetails!;
    final activeEntries = tx.entries.where((e) => e.deletedAt == null).toList();

    // Проверяем, что это не последний entry
    if (activeEntries.length <= 1) {
      await MessageUtils.showError(
        context,
        AppStrings.transactionDetailsCannotDeleteLastEntry,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.transactionDetailsDeleteConfirmTitle),
        content: const Text(AppStrings.transactionDetailsDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.transactionDetailsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppStrings.transactionDetailsDeleteConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTransactionEntry(entryIndex);
    }
  }

  Future<void> _deleteTransactionEntry(int entryIndex) async {
    final tx = transactionDetails;
    if (tx == null) return;

    final activeEntries = tx.entries.where((e) => e.deletedAt == null).toList();
    if (entryIndex >= activeEntries.length) return;

    debugPrint('[TX_DETAILS] === DELETE TRANSACTION ENTRY ===');
    debugPrint('[TX_DETAILS] Entry index: $entryIndex');
    debugPrint(
      '[TX_DETAILS] Deleting entry: ${activeEntries[entryIndex].transactionEntryId ?? activeEntries[entryIndex].id}',
    );

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Create updated entries list excluding the deleted entry
      final updatedEntries = <Map<String, dynamic>>[];
      for (int i = 0; i < activeEntries.length; i++) {
        if (i != entryIndex) {
          // Исключаем удаляемый entry
          final entry = activeEntries[i];
          final categoryId = entry.categoryId ?? entry.category?.categoryId;
          if (categoryId != null && categoryId.isNotEmpty) {
            updatedEntries.add(
              TransactionUpdatePayload.createTransactionEntry(
                id: entry.transactionEntryId ?? entry.id,
                description: entry.description,
                amount: entry.amount,
                categoryId: categoryId,
              ),
            );
          }
        }
      }

      // Create complete payload with updated entries (excluding deleted entry)
      final payload = TransactionUpdatePayload(
        userId: tx.userId,
        groupId: tx.groupId,
        balanceId: tx.balanceId,
        type: tx.type,
        operationId: tx.operationId,
        approvedAt: tx.approvedAt,
        transactedAt: tx.transactedAt ?? tx.approvedAt ?? tx.createdAt,
        transactionEntries: updatedEntries,
        merchantId: tx.merchantId,
      );

      debugPrint(
        '[TX_DETAILS] Complete payload: ${jsonEncode(payload.toJson())}',
      );

      await ApiService.updateTransaction(
        transactionId: widget.transactionId,
        payload: payload,
      );

      // Update transaction entries provider to reflect changes
      if (mounted) {
        final entriesProvider = context.read<TransactionEntriesProvider>();
        await entriesProvider.refreshAfterTransactionUpdate();
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await MessageUtils.showSuccess(
          context,
          AppStrings.transactionDetailsEntryDeleted,
        );
        await fetchTransactionDetails(); // Refresh transaction data
      }
    } catch (e) {
      debugPrint('[TX_DETAILS] Failed to delete entry: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await MessageUtils.showError(context, 'Error deleting entry: $e');
      }
    }
  }

  Future<void> _showDeleteTransactionConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.transactionDeleteConfirmTitle),
        content: const Text(AppStrings.transactionDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.transactionDetailsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppStrings.transactionDeleteConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTransaction();
    }
  }

  Future<void> _deleteTransaction() async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      debugPrint('[TX_DETAILS] === DELETE TRANSACTION ===');
      debugPrint('[TX_DETAILS] Deleting transaction: ${widget.transactionId}');

      await ApiService.deleteTransaction(widget.transactionId);

      // Update transaction entries provider to reflect changes
      if (mounted) {
        final entriesProvider = context.read<TransactionEntriesProvider>();
        await entriesProvider.refreshAfterTransactionUpdate();
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        // Navigate back with success result
        Navigator.of(
          context,
        ).pop({'success': true, 'message': AppStrings.transactionDeleted});
      }
    } catch (e) {
      debugPrint('[TX_DETAILS] Failed to delete transaction: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await MessageUtils.showError(context, 'Error deleting transaction: $e');
      }
    }
  }
}
