import 'package:flutter/material.dart';
import '../models/transaction_entry_data.dart';
import '../services/api_service.dart';
import '../models/transaction_type.dart';
import '../models/transaction_entry.dart';
import 'base_provider.dart';

class TransactionEntriesProvider extends BaseProvider {
  TransactionEntriesProvider();

  List<TransactionEntryData> _entries = [];
  static const Duration _cacheDuration = Duration(minutes: 15);

  List<TransactionEntryData> get entries => _entries;
  String? get error => errorMessage;

  Future<void> loadEntries({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        !shouldRefresh(_cacheDuration) &&
        _entries.isNotEmpty) {
      return;
    }
    await execute(() async {
      final response = await ApiService.getTransactions();
      _entries = response.transactionEntries;
      debugPrint(
          '[TransactionEntriesProvider] loaded ${_entries.length} entries');
    });
  }

  Future<void> createTransaction({
    required TransactionType type,
    double? amount,
    required DateTime date,
    required String categoryId,
    required String balanceId,
    String? description,
    String? merchant,
    List<TransactionEntry>? transactionEntriesParam,
  }) async {
    await execute(() async {
      await ApiService.postTransaction(
        type: type,
        amount: amount,
        date: date,
        categoryId: categoryId,
        balanceId: balanceId,
        description: description,
        merchant: merchant,
        transactionEntriesParam: transactionEntriesParam,
      );
      await loadEntries(forceRefresh: true);
    });
  }

  Future<Map<String, dynamic>?> getTransactionById(String transactionId) async {
    try {
      final data = await execute(() async {
        return await ApiService.getTransactionById(transactionId);
      });
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Refresh entries data after transaction update
  Future<void> refreshAfterTransactionUpdate() async {
    debugPrint(
        '[TransactionEntriesProvider] Refreshing entries after transaction update');
    await loadEntries(forceRefresh: true);
  }

  void clearData() {
    _entries = [];
    notifyListeners();
  }
}
