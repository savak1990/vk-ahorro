import 'package:flutter/material.dart';
import '../models/balance.dart';
import '../services/api_service.dart';
import 'base_provider.dart';

class BalancesProvider extends BaseProvider {
  BalancesProvider();

  List<Balance> _balances = [];
  static const Duration _cacheDuration = Duration(minutes: 60);

  /// Возвращает только активные балансы (без deletedAt)
  List<Balance> get balances {
    final activeBalances = _balances
        .where((balance) => balance.deletedAt == null)
        .toList();
    debugPrint(
      '[BalancesProvider]: get balances called - returning ${activeBalances.length} active balances out of ${_balances.length} total',
    );
    return activeBalances;
  }

  /// Возвращает все балансы (включая удаленные) - для отладки
  List<Balance> get allBalances => _balances;

  String? get error => errorMessage;

  Future<void> loadBalances({bool forceRefresh = false}) async {
    debugPrint(
      '[BalancesProvider]: loadBalances called - forceRefresh: $forceRefresh',
    );
    debugPrint(
      '[BalancesProvider]: Current state - _balances.length: ${_balances.length}, shouldRefresh: ${shouldRefresh(_cacheDuration)}',
    );

    if (!forceRefresh &&
        !shouldRefresh(_cacheDuration) &&
        _balances.isNotEmpty) {
      debugPrint('[BalancesProvider]: Using cached data, skipping API call');
      return;
    }

    debugPrint('[BalancesProvider]: Starting API call to load balances');
    await execute(() async {
      try {
        debugPrint('[BalancesProvider]: Calling ApiService.getBalances()');
        _balances = await ApiService.getBalances();

        final activeBalances = _balances
            .where((balance) => balance.deletedAt == null)
            .length;

        debugPrint('[BalancesProvider]: API call successful');
        debugPrint(
          '[BalancesProvider]: Loaded ${_balances.length} balances total, $activeBalances active',
        );

        // Log first few balance titles for debugging
        if (_balances.isNotEmpty) {
          final titles = _balances.take(3).map((b) => b.title).join(', ');
          debugPrint('[BalancesProvider]: Sample balance titles: $titles');
        }
      } catch (e) {
        debugPrint('[BalancesProvider]: API call failed with error: $e');
        rethrow;
      }
    });
  }

  void clearData() {
    debugPrint(
      '[BalancesProvider]: clearData called - clearing ${_balances.length} balances',
    );
    _balances = [];
    notifyListeners();
  }

  Future<void> createBalance({
    required String userId,
    required String groupId,
    required String currency,
    required String title,
    String? description,
  }) async {
    await execute(() async {
      final response = await ApiService.postBalance(
        userId: userId,
        groupId: groupId,
        currency: currency,
        title: title,
        description: description,
      );

      if (response != null) {
        final newBalance = Balance.fromJson(response);
        _balances.add(newBalance);
        debugPrint(
          '[BalancesProvider]: Added new balance: ${newBalance.title}',
        );
      }
    });
  }

  Future<void> deleteBalance(String balanceId) async {
    if (balanceId.trim().isEmpty) {
      setErrorMessage('ID баланса не может быть пустым');
      return;
    }

    await execute(() async {
      await ApiService.deleteBalance(balanceId);
      _balances.removeWhere((balance) => balance.balanceId == balanceId);
      debugPrint('[BalancesProvider]: Deleted balance: $balanceId');
    });
  }
}
