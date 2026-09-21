import 'package:flutter/material.dart';
import '../providers/transaction_entries_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/balances_provider.dart';
import '../providers/amplify_provider.dart';

class AppStateProvider extends ChangeNotifier {
  final AmplifyProvider _amplify;
  final TransactionEntriesProvider _transactions;
  final CategoriesProvider _categories;
  final BalancesProvider _balances;

  AppStateProvider()
    : _amplify = AmplifyProvider(),
      _transactions = TransactionEntriesProvider(),
      _categories = CategoriesProvider(),
      _balances = BalancesProvider();

  AmplifyProvider get amplify => _amplify;
  TransactionEntriesProvider get transactions => _transactions;
  CategoriesProvider get categories => _categories;
  BalancesProvider get balances => _balances;

  Future<void> initializeApp(String amplifyconfig) async {
    await _amplify.configure(amplifyconfig);
    await _amplify.loadCurrentUserName();
    await Future.wait([
      _categories.loadCategories(),
      _balances.loadBalances(),
      _transactions.loadEntries(),
    ]);
  }

  Future<void> refreshAllData() async {
    await Future.wait([
      _categories.loadCategories(forceRefresh: true),
      _balances.loadBalances(forceRefresh: true),
      _transactions.loadEntries(forceRefresh: true),
    ]);
  }

  /// Called after successful sign-in to load user data
  Future<void> onUserSignedIn() async {
    debugPrint('[AppStateProvider]: User signed in, loading user data');
    await _amplify.loadCurrentUserName();
    await Future.wait([
      _categories.loadCategories(),
      _balances.loadBalances(),
      _transactions.loadEntries(),
    ]);
    debugPrint('[AppStateProvider]: User data loaded successfully');
  }

  void clearAllUserData() {
    // Clear user data from all providers
    _amplify.clearUserData();
    _transactions.clearData();
    _categories.clearData();
    _balances.clearData();
  }

  bool get isAnyLoading =>
      _transactions.isLoading ||
      _categories.isLoading ||
      _balances.isLoading ||
      _amplify.isLoading;

  String? get firstError =>
      _amplify.errorMessage ??
      _transactions.errorMessage ??
      _categories.errorMessage ??
      _balances.errorMessage;

  @override
  void dispose() {
    _transactions.dispose();
    _categories.dispose();
    _balances.dispose();
    _amplify.dispose();
    super.dispose();
  }
}
